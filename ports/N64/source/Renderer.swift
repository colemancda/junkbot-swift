import CN64

/// Software rasterizer for the N64's single 320x240 screen: executes the engine's
/// `RenderCommand` list (world-space, see `RenderCommand.swift`) into the display's
/// native 16bpp 5551 framebuffer (RRRRR GGGGG BBBBB A), offset by the analog-stick
/// -scrolled viewport. No RDP texture pipeline is used -- TMEM is only 4KB, far too
/// small to cache ~200 distinct sprites/frame -- so this CPU-blits pixels directly
/// into the buffer libdragon hands back from `n64_display_attach`, matching
/// ports/3DS's and ports/NDS's Renderer.swift almost exactly. Nothing per-sprite
/// crosses the Swift<->C boundary: the frame's pointer/stride is fetched once.
///
/// Unlike ports/3DS (much larger flash/RAM budget than the N64's, which loads its
/// *entire* ELF -- code, sprites, audio, everything -- into just 4MB of RDRAM at
/// boot, with no separate large-flash tier to lean on the way 3DS/NDS have),
/// sprite pixels here follow ports/NDS's budget instead: 8bpp palette indices
/// (tools/gen_assets.py, copied verbatim) into a shared BGR555 palette (DS
/// hardware color order, see `packRGBA5551` below), sprite sheets only (no
/// background-sheet images -- the screen clears to each backdrop's average
/// color instead, generated into `spriteAverageColorTable`).

let screenWidth: Int32 = 320
let screenHeight: Int32 = 240

/// `sprites.bin`'s pixel data (palette indices, one byte per pixel).
let spritePixels: UnsafePointer<UInt8> =
  n64_asset_sprites_bin()!.assumingMemoryBound(to: UInt8.self)

/// DS-style BGR555 (bit15 set = opaque, blue in the top bits -- gen_assets.py's
/// palette/average-color tables are copied verbatim from ports/NDS, which packs
/// colors to match the DS's own BGR555 hardware format) -> N64 display 5551
/// (RRRRR GGGGG BBBBB A). Same 5-bit channels, just reordered -- getting this
/// backwards silently swaps red and blue (e.g. Junkbot's orange render as blue).
@inline(__always)
func packRGBA5551(fromBGR555 bgr555: UInt16) -> UInt16 {
  let b = (bgr555 >> 10) & 0x1F
  let g = (bgr555 >> 5) & 0x1F
  let r = bgr555 & 0x1F
  return (r << 11) | (g << 6) | (b << 1) | 1
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
  _ cmd: RenderCommand, into buffer: UnsafeMutablePointer<UInt16>, strideElements: Int32,
  palette: UnsafePointer<UInt16>, scrollX: Int32, scrollY: Int32
) {
  let id = Int(cmd.spriteID)
  guard id >= 0, id < spriteDataOffsetTable.count else { return }
  let offset = spriteDataOffsetTable[id]
  guard offset >= 0 else { return }  // gap slot or background sheet (not embedded)

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
    let dstRow = buffer + Int(dy) * Int(strideElements)
    var dx = x0
    while dx < x1 {
      let index = srcRow[Int(dx &- screenX)]
      // Palette index 0 = transparent (gen_assets.py maps alpha < 128 to 0).
      if index != 0,
        alpha >= 100 || !ditherSkips(x: dx, y: dy, alphaPercent: alpha)
      {
        dstRow[Int(dx)] = packRGBA5551(fromBGR555: palette[Int(index)])
      }
      dx &+= 1
    }
    dy &+= 1
  }
}

func fillRect(
  _ cmd: RenderCommand, into buffer: UnsafeMutablePointer<UInt16>, strideElements: Int32,
  scrollX: Int32, scrollY: Int32
) {
  let rgba = UInt32(bitPattern: cmd.c)
  let alpha = Int32((rgba & 0xFF) &* 100 / 255)
  guard alpha > 0 else { return }
  let r = UInt16((rgba >> 27) & 0x1F)
  let g5 = UInt16((rgba >> 19) & 0x1F)
  let b = UInt16((rgba >> 11) & 0x1F)
  let color = packRGBA5551(fromBGR555: 0x8000 | (b << 10) | (g5 << 5) | r)

  let screenX = cmd.x &- scrollX
  let screenY = cmd.y &- scrollY
  let x0 = max(0, screenX), y0 = max(0, screenY)
  let x1 = min(screenWidth, screenX &+ cmd.a)  // a = width
  let y1 = min(screenHeight, screenY &+ cmd.b)  // b = height
  guard x0 < x1, y0 < y1 else { return }

  var dy = y0
  while dy < y1 {
    let dstRow = buffer + Int(dy) * Int(strideElements)
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

/// Set by main.swift: draws the HUD overlay (level number, moves, win/lose
/// prompt) directly into the world's own framebuffer, since the N64's single
/// screen has no separate text-console surface like ports/3DS/ports/NDS.
var hudDrawHook: ((UnsafeMutablePointer<UInt16>, Int32) -> Void)?

/// Rebuilds the engine's command list and rasterizes it directly into the
/// display buffer libdragon hands back for this frame, then presents it.
///
/// The background pass (`commands[0..<backgroundCount]`, backdrop + decals) is
/// skipped, same as ports/NDS: those images live on the backgrounds sheet,
/// which even at 8bpp would blow well past the N64's 4MB whole-ELF budget.
/// Instead the screen clears to the backdrop's average color (generated per-
/// backdrop into `spriteAverageColorTable`).
func renderWorld(scrollX: Int32, scrollY: Int32) {
  gameEngine.buildRenderFrame(into: &renderFrame, editing: false)

  var width: Int32 = 0
  var height: Int32 = 0
  var strideBytes: Int32 = 0
  let address = n64_display_attach(&width, &height, &strideBytes)
  let buffer = UnsafeMutablePointer<UInt16>(bitPattern: UInt(address))!
  let strideElements = strideBytes / 2

  var clearBGR555: UInt16 = 0x8000 | (14 << 10) | (17 << 5) | 18  // fallback warm gray (R=18 G=17 B=14)
  if renderFrame.backgroundCount > 0 {
    let firstID = Int(renderFrame.commands[0].spriteID)
    if firstID >= 0, firstID < spriteAverageColorTable.count,
      spriteAverageColorTable[firstID] != 0
    {
      clearBGR555 = spriteAverageColorTable[firstID]
    }
  }
  let clearColor = packRGBA5551(fromBGR555: clearBGR555)
  buffer.update(repeating: clearColor, count: Int(strideElements * height))

  spritePaletteTable.withUnsafeBufferPointer { paletteBuffer in
    let palette = paletteBuffer.baseAddress!
    var index = renderFrame.backgroundCount
    while index < renderFrame.commands.count {
      let cmd = renderFrame.commands[index]
      switch cmd.kind {
      case .sprite:
        blitSprite(cmd, into: buffer, strideElements: strideElements, palette: palette, scrollX: scrollX, scrollY: scrollY)
      case .solidRect:
        fillRect(cmd, into: buffer, strideElements: strideElements, scrollX: scrollX, scrollY: scrollY)
      }
      index += 1
    }
  }

  hudDrawHook?(buffer, strideElements)

  n64_display_show()
}
