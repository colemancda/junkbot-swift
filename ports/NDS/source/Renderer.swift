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

/// `backdrops.bin`'s pixel data (palette indices, one byte per pixel) - the five room backdrops
/// (`bkg1`...`bkg5`), downscaled at build time (`tools/gen_backdrops.py`) since the full-size
/// artwork alone would roughly double the ARM9 image's ROM budget. Only ~10 unique colors per
/// backdrop, so the downscale is lossless in color even though it's blocky in shape.
let backdropPixels: UnsafePointer<UInt8> =
  nds_asset_backdrops_bin()!.assumingMemoryBound(to: UInt8.self)

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

/// Draws the current level's downscaled room backdrop (if it has embedded art - see
/// `tools/gen_backdrops.py`), nearest-neighbor-sampled back up to `bounds`' actual size, cropped
/// to whatever part of it the current scroll position shows. Returns `false` (nothing drawn) for
/// a sprite ID with no embedded backdrop data, so the caller can fall back to a flat clear.
///
/// Scale factors are precomputed once as 24.8 fixed-point steps and then only ever *added*
/// per pixel/row - the ARM946E-S has no hardware integer divide, so the naive per-pixel
/// `(world - origin) * src / bounds` (a real division every one of the 49152 pixels) cost enough
/// software-divide cycles to visibly slow the whole game down. Incremental fixed-point stepping
/// needs only 2 divisions total (building the steps), not one per pixel.
///
/// (A hardware-affine-background version of this was tried and reverted - see git history/PR
/// discussion - the BG2 scale/scroll register math came out wrong on first pass, rendering
/// garbage; reverted to this known-good software version rather than debug PPU affine register
/// semantics blind. Worth revisiting.)
func blitBackdrop(
  spriteID: Int32, bounds: LevelBounds, scrollX: Int32, scrollY: Int32,
  into buffer: UnsafeMutablePointer<UInt16>
) -> Bool {
  guard spriteID >= 0, Int(spriteID) < backdropOffsetTable.count else { return false }
  let offset = backdropOffsetTable[Int(spriteID)]
  guard offset >= 0 else { return false }

  let srcWidth = backdropWidthTable[Int(spriteID)]
  let srcHeight = backdropHeightTable[Int(spriteID)]
  let paletteOffset = Int(backdropPaletteOffsetTable[Int(spriteID)])
  let src = backdropPixels + Int(offset)
  let boundsWidth = max(bounds.width, 1)
  let boundsHeight = max(bounds.height, 1)

  // 24.8 fixed-point world-pixel -> backdrop-pixel step (the only two divisions).
  let stepX = (srcWidth << 8) / boundsWidth
  let stepY = (srcHeight << 8) / boundsHeight
  let maxXFixed = (srcWidth - 1) << 8
  let maxYFixed = (srcHeight - 1) << 8

  backdropPaletteTable.withUnsafeBufferPointer { paletteBuffer in
    let palette = paletteBuffer.baseAddress! + paletteOffset
    var dy: Int32 = 0
    var srcYFixed = (scrollY &- bounds.y) &* stepY
    while dy < screenHeight {
      let srcY = min(max(srcYFixed, 0), maxYFixed) >> 8
      let srcRowBase = Int(srcY) * Int(srcWidth)
      let dstRowBase = Int(dy) * Int(screenWidth)

      var srcXFixed = (scrollX &- bounds.x) &* stepX
      var dx: Int32 = 0
      while dx < screenWidth {
        let srcX = min(max(srcXFixed, 0), maxXFixed) >> 8
        let index = src[srcRowBase + Int(srcX)]
        buffer[dstRowBase + Int(dx)] = palette[Int(index)]
        srcXFixed &+= stepX
        dx &+= 1
      }
      srcYFixed &+= stepY
      dy &+= 1
    }
  }
  return true
}

/// Rebuilds the engine's command list and rasterizes it into `buffer`.
///
/// The background pass (`commands[0..<backgroundCount]`, backdrop + decals) mostly stays
/// skipped: decal images live on the backgrounds sheet, which at 16bpp would exceed the DS's
/// ROM budget all by itself. The room backdrop itself is the exception - a heavily downscaled
/// copy is small enough to embed (`blitBackdrop` above) - so only decals fall back to nothing
/// drawn; the screen clears to the backdrop's own average color first (covers any edge pixels
/// `blitBackdrop`'s nearest-neighbor sampling doesn't reach, and is the fallback for a sprite ID
/// with no embedded backdrop art at all).
func renderWorld(
  into buffer: UnsafeMutablePointer<UInt16>, scrollX: Int32, scrollY: Int32
) {
  // A busy level can have 100+ entities scattered across a world far larger than one 256x192
  // screen; culling to what's actually visible (plus a margin for sprites straddling the edge)
  // keeps buildRenderFrame's entity-sort pass cheap regardless of level size -- see that
  // function's doc comment for why this matters on the DS's ARM946E-S.
  let margin: Int32 = 64
  let visible = LevelBounds(
    x: scrollX - margin, y: scrollY - margin,
    width: screenWidth + margin * 2, height: screenHeight + margin * 2)
  gameEngine.buildRenderFrame(into: &renderFrame, editing: false, visibleBounds: visible)

  var clearColor: UInt16 = 0x8000 | (14 << 10) | (17 << 5) | 18  // fallback warm gray
  var backdropSpriteID: Int32 = -1
  if renderFrame.backgroundCount > 0 {
    backdropSpriteID = renderFrame.commands[0].spriteID
    let firstID = Int(backdropSpriteID)
    if firstID >= 0, firstID < spriteAverageColorTable.count,
      spriteAverageColorTable[firstID] != 0
    {
      clearColor = spriteAverageColorTable[firstID]
    }
  }
  dmaFillHalfWords(clearColor, buffer, UInt32(screenWidth * screenHeight) * 2)

  if let bounds = gameEngine.levelBounds {
    _ = blitBackdrop(
      spriteID: backdropSpriteID, bounds: bounds, scrollX: scrollX, scrollY: scrollY,
      into: buffer)
  }

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
