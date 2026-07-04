import CTRU

/// Software rasterizer for the 3DS's bottom (touch) screen: executes the engine's
/// `RenderCommand` list (world-space, see `RenderCommand.swift`) into a 16bpp
/// RGB565 row-major canvas, offset by the D-pad-scrolled viewport. The canvas is
/// handed to `ctru_present_bottom` each dirty frame, which transposes it into the
/// bottom LCD's column-major hardware framebuffer (see common/shim.c).
///
/// Sprite pixel data is the bin2s-embedded `sprites.bin`: one `UInt16` per pixel,
/// bit 15 set for an opaque RGB555 color, 0 for transparent (`tools/gen_assets.py`).
/// Unlike the DS port, the 3DS's much larger RAM budget means background-sheet
/// images are embedded too (no shared/limited palette, no per-backdrop average-color
/// fallback) -- the whole render-command list, backgrounds included, is rasterized
/// the same way.

let screenWidth: Int32 = 320
let screenHeight: Int32 = 240

/// `sprites.bin`'s pixel data: one `UInt16` per pixel (bit15 set = opaque RGB555,
/// 0 = transparent). `spriteDataOffsetTable` values are element (not byte) offsets.
let spritePixels: UnsafePointer<UInt16> =
  ctru_asset_sprites_bin()!.assumingMemoryBound(to: UInt16.self)

/// RGB555 (bit15 set) -> 3DS RGB565. RGB565 packs as rrrrr gggggg bbbbb
/// (b at bits 0-4, g at bits 5-10, r at bits 11-15, per libctru's own
/// `RGB565` macro) -- the 5-bit green needs widening to 6 bits by
/// replicating its low bit, same as any 555->565 upconvert.
@inline(__always)
func rgb565(fromRGB555 rgb555: UInt16) -> UInt16 {
  let r = (rgb555 >> 10) & 0x1F
  let g = (rgb555 >> 5) & 0x1F
  let b = rgb555 & 0x1F
  let g6 = (g << 1) | (g >> 4)
  return (r << 11) | (g6 << 5) | b
}

/// Ordered-dither test for translucent draws (the engine emits alpha as a
/// 0...100 percent). True = skip this pixel -- simple and fast; a real alpha
/// blend isn't needed for a puzzle game's occasional ghost/effect overlays.
@inline(__always)
func ditherSkips(x: Int32, y: Int32, alphaPercent: Int32) -> Bool {
  let d = (x &+ y) & 3
  if alphaPercent >= 70 { return d == 3 }  // draw ~3/4
  if alphaPercent >= 45 { return (x &+ y) & 1 != 0 }  // draw 1/2
  return d != 0  // draw ~1/4
}

func blitSprite(
  _ cmd: RenderCommand, into buffer: UnsafeMutablePointer<UInt16>, scrollX: Int32, scrollY: Int32
) {
  let id = Int(cmd.spriteID)
  guard id >= 0, id < spriteDataOffsetTable.count else { return }
  let offset = spriteDataOffsetTable[id]
  guard offset >= 0 else { return }  // gap slot

  let spriteW = spriteWidthTable[id]
  let spriteH = spriteHeightTable[id]
  // `c` > 0 clips the source/destination width (laser-beam final segment).
  let visibleW = cmd.c > 0 ? min(spriteW, cmd.c) : spriteW

  let screenX = cmd.x &- scrollX
  let screenY = cmd.y &- scrollY
  let x0 = max(0, screenX), y0 = max(0, screenY)
  let x1 = min(screenWidth, screenX &+ visibleW)
  let y1 = min(screenHeight, screenY &+ spriteH)
  guard x0 < x1, y0 < y1 else { return }

  let alpha = cmd.a
  let src = spritePixels + Int(offset)
  var dy = y0
  while dy < y1 {
    let srcRow = src + Int(dy &- screenY) * Int(spriteW)
    let dstRow = buffer + Int(dy) * Int(screenWidth)
    var dx = x0
    while dx < x1 {
      let pixel = srcRow[Int(dx &- screenX)]
      // Bit 15 = opaque; 0 = transparent (gen_assets.py maps alpha < 128 to 0).
      if pixel & 0x8000 != 0,
        alpha >= 100 || !ditherSkips(x: dx, y: dy, alphaPercent: alpha)
      {
        dstRow[Int(dx)] = rgb565(fromRGB555: pixel)
      }
      dx &+= 1
    }
    dy &+= 1
  }
}

func fillRect(
  _ cmd: RenderCommand, into buffer: UnsafeMutablePointer<UInt16>, scrollX: Int32, scrollY: Int32
) {
  let rgba = UInt32(bitPattern: cmd.c)
  let alpha = Int32((rgba & 0xFF) &* 100 / 255)
  guard alpha > 0 else { return }
  let r = UInt16((rgba >> 27) & 0x1F)
  let g5 = UInt16((rgba >> 19) & 0x1F)
  let b = UInt16((rgba >> 11) & 0x1F)
  let color = rgb565(fromRGB555: (r << 10) | (g5 << 5) | b)

  let screenX = cmd.x &- scrollX
  let screenY = cmd.y &- scrollY
  let x0 = max(0, screenX), y0 = max(0, screenY)
  let x1 = min(screenWidth, screenX &+ cmd.a)  // a = width
  let y1 = min(screenHeight, screenY &+ cmd.b)  // b = height
  guard x0 < x1, y0 < y1 else { return }

  var dy = y0
  while dy < y1 {
    let dstRow = buffer + Int(dy) * Int(screenWidth)
    var dx = x0
    while dx < x1 {
      if alpha >= 100 || !ditherSkips(x: dx, y: dy, alphaPercent: alpha) {
        dstRow[Int(dx)] = color
      }
      dx &+= 1
    }
    dy &+= 1
  }
}

/// Persistent frame storage (`buildRenderFrame` reuses the command array's
/// capacity across frames).
var renderFrame = RenderFrame()

/// The row-major RGB565 canvas `ctru_present_bottom` transposes into the
/// bottom LCD's framebuffer each dirty frame. Allocated once; the 3DS has
/// plenty of RAM for a single persistent 320x240x2 buffer (150KB).
let canvas = UnsafeMutablePointer<UInt16>.allocate(capacity: Int(screenWidth * screenHeight))

/// Rebuilds the engine's command list and rasterizes it (backgrounds included --
/// unlike the DS port, there's no RAM pressure forcing an average-color clear
/// instead) into `canvas`, then presents it.
func renderWorld(scrollX: Int32, scrollY: Int32) {
  gameEngine.buildRenderFrame(into: &renderFrame, editing: false)

  canvas.update(repeating: 0, count: Int(screenWidth * screenHeight))

  for cmd in renderFrame.commands {
    switch cmd.kind {
    case .sprite:
      blitSprite(cmd, into: canvas, scrollX: scrollX, scrollY: scrollY)
    case .solidRect:
      fillRect(cmd, into: canvas, scrollX: scrollX, scrollY: scrollY)
    }
  }

  ctru_present_bottom(canvas, screenWidth, screenHeight)
}
