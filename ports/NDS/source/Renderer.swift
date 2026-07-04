import CNDS

/// Software rasterizer for the DS's bottom screen: executes the engine's
/// `RenderCommand` list (world-space, see `RenderCommand.swift`) into a 16bpp
/// bitmap background back buffer, offset by the D-pad-scrolled viewport.
///
/// Sprite pixel data is the bin2s-embedded `sprites.bin`: 8bpp indices into
/// the shared `spritePaletteTable` (index 0 = transparent), lossless because
/// the whole art set has fewer than 255 unique RGB555 colors. Frame
/// dimensions come from the core's generated `spriteWidthTable`/
/// `spriteHeightTable`; offsets from the generated `spriteDataOffsetTable`
/// (`build/SpriteAssets.swift`).

let screenWidth: Int32 = 256
let screenHeight: Int32 = 192

/// `sprites.bin`'s pixel data (palette indices, one byte per pixel).
let spritePixels: UnsafePointer<UInt8> =
  nds_asset_sprites_bin()!.assumingMemoryBound(to: UInt8.self)

/// 0xRRGGBBAA (RenderCommand.solidRect's color encoding) -> DS RGB555.
@inline(__always)
func rgb15(fromRGBA rgba: UInt32) -> UInt16 {
  let r = UInt16((rgba >> 27) & 0x1F)
  let g = UInt16((rgba >> 19) & 0x1F)
  let b = UInt16((rgba >> 11) & 0x1F)
  return 0x8000 | (b << 10) | (g << 5) | r
}

/// Ordered-dither test for translucent draws (the engine emits alpha as a
/// 0...100 percent). True = skip this pixel. Three levels approximate the
/// engine's actual usage (80 = draggable ghost, 50 = wind/effects, 30 =
/// unplaceable ghost) on a screen with no alpha blending in bitmap modes.
@inline(__always)
func ditherSkips(x: Int32, y: Int32, alphaPercent: Int32) -> Bool {
  let d = (x &+ y) & 3
  if alphaPercent >= 70 { return d == 3 }  // draw ~3/4
  if alphaPercent >= 45 { return (x &+ y) & 1 != 0 }  // draw 1/2
  return d != 0  // draw ~1/4
}

func blitSprite(
  _ cmd: RenderCommand, into buffer: UnsafeMutablePointer<UInt16>,
  palette: UnsafePointer<UInt16>, scrollX: Int32, scrollY: Int32
) {
  let id = Int(cmd.spriteID)
  guard id >= 0, id < spriteDataOffsetTable.count else { return }
  let offset = spriteDataOffsetTable[id]
  guard offset >= 0 else { return }  // gap slot or background sheet (not on DS)

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
      let index = srcRow[Int(dx &- screenX)]
      // Palette index 0 = transparent (gen_assets.py maps alpha < 128 to 0).
      if index != 0,
        alpha >= 100 || !ditherSkips(x: dx, y: dy, alphaPercent: alpha)
      {
        dstRow[Int(dx)] = palette[Int(index)]
      }
      dx &+= 1
    }
    dy &+= 1
  }
}

func fillRect(
  _ cmd: RenderCommand, into buffer: UnsafeMutablePointer<UInt16>,
  scrollX: Int32, scrollY: Int32
) {
  let rgba = UInt32(bitPattern: cmd.c)
  let alpha = Int32((rgba & 0xFF) &* 100 / 255)
  guard alpha > 0 else { return }
  let color = rgb15(fromRGBA: rgba)

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

/// Rebuilds the engine's command list and rasterizes it into `buffer`.
///
/// The background pass (`commands[0..<backgroundCount]`, backdrop + decals) is
/// skipped: those images live on the backgrounds sheet, which at 16bpp would
/// exceed the DS's 4MB RAM all by itself. Instead the screen clears to the
/// backdrop's average color (generated per-backdrop into
/// `spriteAverageColorTable`).
func renderWorld(
  into buffer: UnsafeMutablePointer<UInt16>, scrollX: Int32, scrollY: Int32
) {
  gameEngine.buildRenderFrame(into: &renderFrame, editing: false)

  var clearColor: UInt16 = 0x8000 | (14 << 10) | (17 << 5) | 18  // fallback warm gray
  if renderFrame.backgroundCount > 0 {
    let firstID = Int(renderFrame.commands[0].spriteID)
    if firstID >= 0, firstID < spriteAverageColorTable.count,
      spriteAverageColorTable[firstID] != 0
    {
      clearColor = spriteAverageColorTable[firstID]
    }
  }
  dmaFillHalfWords(clearColor, buffer, UInt32(screenWidth * screenHeight) * 2)

  spritePaletteTable.withUnsafeBufferPointer { paletteBuffer in
    let palette = paletteBuffer.baseAddress!
    var index = renderFrame.backgroundCount
    while index < renderFrame.commands.count {
      let cmd = renderFrame.commands[index]
      switch cmd.kind {
      case .sprite:
        blitSprite(cmd, into: buffer, palette: palette, scrollX: scrollX, scrollY: scrollY)
      case .solidRect:
        fillRect(cmd, into: buffer, scrollX: scrollX, scrollY: scrollY)
      }
      index += 1
    }
  }
}
