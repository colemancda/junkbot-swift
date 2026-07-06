// ports/PS1/source/Renderer.swift — software rasterizer for the PS1's single
// 320x240 screen, adapted directly from ports/N64/source/Renderer.swift.
//
// PS1 VRAM isn't CPU-addressable the way N64's memory-mapped RDRAM
// framebuffer is -- pixels only reach the screen through a GPU DMA transfer
// (LoadImage2). So this renders into a RAM-side UInt16 buffer
// (ps1_world_framebuffer(), common/shim.c) using the exact same per-pixel
// blit algorithm N64 uses, then hands the whole frame to the GPU in one shot
// (ps1_present_world()) before the HUD text (drawn via the ordering
// table/FntSort) and the double-buffer flip.
//
// Sprite pixels are 8bpp palette indices into a shared BGR555 palette
// (tools/gen_assets.py, copied verbatim from ports/N64/ports/NDS — same
// generated SpriteAssets.swift/build pipeline).

let screenWidth: Int32 = 320
let screenHeight: Int32 = 240

/// `sprites.bin`'s pixel data (palette indices, one byte per pixel).
let spritePixels: UnsafePointer<UInt8> =
  UnsafeRawPointer(ps1_asset_sprites_bin()!).assumingMemoryBound(to: UInt8.self)

/// gen_assets.py's palette entries are BGR555 with bit15 forced to 1 (an N64/DS
/// hardware "opaque" convention). PS1's native 16bpp format is the same B/G/R
/// bit layout, but bit15 is the semi-transparency-enable flag -- must be 0 for
/// a normal opaque blit, so this is just a mask, no channel reordering.
@inline(__always)
func packPS1(fromBGR555 bgr555: UInt16) -> UInt16 {
  bgr555 & 0x7FFF
}

/// Ordered-dither test for translucent draws (engine alpha is 0...100 percent).
/// True = skip this pixel.
@inline(__always)
func ditherSkips(x: Int32, y: Int32, alphaPercent: Int32) -> Bool {
  let d = (x &+ y) & 3
  if alphaPercent >= 70 { return d == 3 }
  if alphaPercent >= 45 { return (x &+ y) & 1 != 0 }
  return d != 0
}

func blitSprite(
  _ cmd: RenderCommand, into buffer: UnsafeMutablePointer<UInt16>, strideElements: Int32,
  palette: UnsafePointer<UInt16>, scrollX: Int32, scrollY: Int32
) {
  let id = Int(cmd.spriteID)
  guard id >= 0, id < spriteDataOffsetTable.count else { return }
  let offset = spriteDataOffsetTable[id]
  guard offset >= 0 else { return }

  let spriteW = spriteWidthTable[id]
  let spriteH = spriteHeightTable[id]
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
      if index != 0,
        alpha >= 100 || !ditherSkips(x: dx, y: dy, alphaPercent: alpha)
      {
        dstRow[Int(dx)] = packPS1(fromBGR555: palette[Int(index)])
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
  let color = packPS1(fromBGR555: (b << 10) | (g5 << 5) | r)

  let screenX = cmd.x &- scrollX
  let screenY = cmd.y &- scrollY
  let x0 = max(0, screenX), y0 = max(0, screenY)
  let x1 = min(screenWidth, screenX &+ cmd.a)
  let y1 = min(screenHeight, screenY &+ cmd.b)
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

var renderFrame = RenderFrame()

/// Set by main.swift: draws HUD overlay text via ps1_draw_text/FntSort,
/// called after the world raster has been handed to the GPU.
var hudDrawHook: (() -> Void)?

func renderWorld(scrollX: Int32, scrollY: Int32) {
  gameEngine.buildRenderFrame(into: &renderFrame, editing: false)

  let buffer = ps1_world_framebuffer()!
  let strideElements: Int32 = screenWidth

  var clearBGR555: UInt16 = (14 << 10) | (17 << 5) | 18  // warm gray fallback
  if renderFrame.backgroundCount > 0 {
    let firstID = Int(renderFrame.commands[0].spriteID)
    if firstID >= 0, firstID < spriteAverageColorTable.count,
      spriteAverageColorTable[firstID] != 0
    {
      clearBGR555 = spriteAverageColorTable[firstID]
    }
  }
  let clearColor = packPS1(fromBGR555: clearBGR555)
  buffer.update(repeating: clearColor, count: Int(strideElements * screenHeight))

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

  ps1_present_world()
  hudDrawHook?()
}
