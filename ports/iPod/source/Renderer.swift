import CRockbox

/// Software rasterizer for the iPod Nano 2G's LCD: executes the engine's
/// `RenderCommand` list (world-space, see `RenderCommand.swift`) into a 16bpp
/// RGB565 row-major canvas, offset by the click-wheel-scrolled viewport. The
/// canvas is a static buffer owned by the C plugin (passed through
/// `junkbot_init`); after each frame C blits it with `rb->lcd_bitmap` — the
/// Nano's framebuffer is row-major, so unlike the 3DS port there is no
/// transpose step here.
///
/// Sprite pixel data is `sprites.bin`: one `UInt16` per pixel, bit15 set for an
/// opaque RGB555 color, 0 for transparent (`tools/gen_assets.py`). Unlike every
/// other Junkbot port, that blob is NOT linked into the binary — it is ~5.6MB,
/// far larger than a Rockbox plugin's own buffer, so the C host loads it from
/// `/.rockbox/junkbot/sprites.bin` into the audio buffer at startup and hands
/// the pointer to `junkbot_init` (see the README's "assets on the filesystem"
/// note). Only the tiny per-sprite offset table (`build/SpriteAssets.swift`) is
/// compiled in.

/// Game viewport: the full 176-wide Nano 2G panel, minus a 12px status strip at
/// the top that the C host draws with Rockbox's own font (level / moves). C
/// blits this canvas at y = `statusStripHeight`.
let screenWidth: Int32 = 176
let screenHeight: Int32 = 120
let statusStripHeight: Int32 = 12

/// `sprites.bin`'s pixel data (one little-endian UInt16 per pixel: bit15 set =
/// opaque RGB555, 0 = transparent). Set once by `junkbot_init` from the buffer
/// the C host loaded the file into. `spriteDataOffsetTable` values are element
/// (not byte) offsets into this.
var spritePixels: UnsafePointer<UInt16>! = nil

/// The row-major RGB565 canvas the C host blits each frame. Owned by C; Swift
/// only writes into it. Set by `junkbot_init`.
var canvas: UnsafeMutablePointer<UInt16>! = nil

/// RGB555 (bit15 set) -> RGB565. RGB565 packs as rrrrr gggggg bbbbb; the 5-bit
/// green widens to 6 bits by replicating its low bit, as in any 555->565
/// upconvert (matches ports/3DS's `rgb565`).
@inline(__always)
func rgb565(fromRGB555 rgb555: UInt16) -> UInt16 {
  let r = (rgb555 >> 10) & 0x1F
  let g = (rgb555 >> 5) & 0x1F
  let b = rgb555 & 0x1F
  let g6 = (g << 1) | (g >> 4)
  return (r << 11) | (g6 << 5) | b
}

/// Ordered-dither test for translucent draws (the engine emits alpha as a
/// 0...100 percent). True = skip this pixel — simple and fast; a real alpha
/// blend isn't needed for a puzzle game's occasional ghost/drag overlays.
@inline(__always)
func ditherSkips(x: Int32, y: Int32, alphaPercent: Int32) -> Bool {
  let d = (x &+ y) & 3
  if alphaPercent >= 70 { return d == 3 }  // draw ~3/4
  if alphaPercent >= 45 { return (x &+ y) & 1 != 0 }  // draw 1/2
  return d != 0  // draw ~1/4
}

func blitSprite(_ cmd: RenderCommand, scrollX: Int32, scrollY: Int32) {
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
    let dstRow = canvas + Int(dy) * Int(screenWidth)
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

func fillRect(_ cmd: RenderCommand, scrollX: Int32, scrollY: Int32) {
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
    let dstRow = canvas + Int(dy) * Int(screenWidth)
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

/// Plots one screen-space pixel with bounds clipping (cursor overlay only —
/// hot-path draws clip once up front instead).
@inline(__always)
func plotClipped(_ x: Int32, _ y: Int32, _ color: UInt16) {
  guard x >= 0, y >= 0, x < screenWidth, y < screenHeight else { return }
  canvas[Int(y) * Int(screenWidth) + Int(x)] = color
}

/// The player's aiming reticle, drawn over the world at the cursor's *screen*
/// position after all entities: a hollow box (one grid cell) plus a center
/// crosshair. Bright yellow when idle, cyan while holding a brick, so the grab
/// state is always visible on a screen with no hardware pointer.
func drawCursor(screenX: Int32, screenY: Int32, grabbing: Bool) {
  let color: UInt16 = grabbing ? 0x07FF /* cyan */ : 0xFFE0 /* yellow */
  let half: Int32 = 6

  // Hollow box outline.
  var dx = -half
  while dx <= half {
    plotClipped(screenX &+ dx, screenY &- half, color)
    plotClipped(screenX &+ dx, screenY &+ half, color)
    dx &+= 1
  }
  var dy = -half
  while dy <= half {
    plotClipped(screenX &- half, screenY &+ dy, color)
    plotClipped(screenX &+ half, screenY &+ dy, color)
    dy &+= 1
  }
  // Center crosshair.
  var i: Int32 = -2
  while i <= 2 {
    plotClipped(screenX &+ i, screenY, color)
    plotClipped(screenX, screenY &+ i, color)
    i &+= 1
  }
}
