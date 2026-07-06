// ports/PS1/source/Renderer.swift — software rasterizer for the PS1's single
// 320x240 screen, adapted directly from ports/N64/source/Renderer.swift.
//
// Milestone (current, per user request): statically render a hardcoded
// viewport -- no Entity, no GameState, no simulation, no input, no audio --
// to validate the rendering pipeline in isolation. See KNOWN_ISSUES.md
// "Update 5" for a THIRD confirmed bug found while bisecting this: a global
// `let` whose initializer is `UnsafeRawPointer(ptr!).assumingMemoryBound(to:)`
// hangs forever, while the exact same expression works fine as a local
// variable. `spritePixels` is therefore computed fresh inside
// renderStaticViewport() every frame (cheap: one function call + a pointer
// cast, no allocation) instead of once as a global.
//
// PS1 VRAM isn't CPU-addressable the way N64's memory-mapped RDRAM
// framebuffer is -- pixels only reach the screen through a GPU DMA transfer
// (LoadImage). So this renders into a RAM-side UInt16 buffer
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
  spriteID: Int32, x: Int32, y: Int32, alpha: Int32,
  spritePixels: UnsafePointer<UInt8>,
  into buffer: UnsafeMutablePointer<UInt16>, strideElements: Int32,
  palette: UnsafePointer<UInt16>
) {
  let id = Int(spriteID)
  guard id >= 0, id < spriteDataOffsetTable.count else { return }
  let offset = spriteDataOffsetTable[id]
  guard offset >= 0 else { return }

  let spriteW = spriteWidthTable[id]
  let spriteH = spriteHeightTable[id]

  let x0 = max(0, x), y0 = max(0, y)
  let x1 = min(screenWidth, x &+ spriteW)
  let y1 = min(screenHeight, y &+ spriteH)
  guard x0 < x1, y0 < y1 else { return }

  let src = spritePixels + Int(offset)
  var dy = y0
  while dy < y1 {
    let srcRow = src + Int(dy &- y) * Int(spriteW)
    let dstRow = buffer + Int(dy) * Int(strideElements)
    var dx = x0
    while dx < x1 {
      let index = srcRow[Int(dx &- x)]
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

/// Set by main.swift: draws HUD overlay text via ps1_draw_text/FntSort,
/// called after the world raster has been handed to the GPU.
var hudDrawHook: (() -> Void)?

func renderStaticViewport() {
  // Computed locally every frame -- see this file's header comment for why
  // (a global `let` with this exact initializer expression hangs on this
  // target; the same expression as a local works fine).
  let spritePixels: UnsafePointer<UInt8> =
    UnsafeRawPointer(ps1_asset_sprites_bin()!).assumingMemoryBound(to: UInt8.self)

  let buffer = ps1_world_framebuffer()!
  let strideElements: Int32 = screenWidth

  let clearBGR555: UInt16 = (14 << 10) | (17 << 5) | 18  // warm gray fallback
  let clearColor = packPS1(fromBGR555: clearBGR555)
  buffer.update(repeating: clearColor, count: Int(strideElements * screenHeight))

  spritePaletteTable.withUnsafeBufferPointer { paletteBuffer in
    let palette = paletteBuffer.baseAddress!

    // A row of 8 ground bricks, a bin, and Junkbot standing -- a
    // representative viewport, built from literal sprite IDs/coordinates
    // (no Entity/GameState/simulation).
    let brickY: Int32 = 10 * CELL_H
    blitSprite(spriteID: SpriteID.brickWhiteBase + 8, x: 0 * CELL_W, y: brickY, alpha: 100, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)
    blitSprite(spriteID: SpriteID.brickRedBase + 8, x: 8 * CELL_W, y: brickY, alpha: 100, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)
    blitSprite(spriteID: SpriteID.brickGreenBase + 8, x: 16 * CELL_W, y: brickY, alpha: 100, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)
    blitSprite(spriteID: SpriteID.brickBlueBase + 8, x: 24 * CELL_W, y: brickY, alpha: 100, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)
    blitSprite(spriteID: SpriteID.brickYellowBase + 8, x: 32 * CELL_W, y: brickY, alpha: 100, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)
    blitSprite(spriteID: SpriteID.brickWhiteBase + 8, x: 40 * CELL_W, y: brickY, alpha: 100, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)
    blitSprite(spriteID: SpriteID.brickRedBase + 8, x: 48 * CELL_W, y: brickY, alpha: 100, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)
    blitSprite(spriteID: SpriteID.brickGreenBase + 8, x: 56 * CELL_W, y: brickY, alpha: 100, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)

    // Bin: entitySprite's bin case, x = e.x+4, y = e.y+e.height-h-5 (RenderList.swift).
    let binH = spriteHeightTable[Int(SpriteID.bin)]
    blitSprite(spriteID: SpriteID.bin, x: 50 * CELL_W + 4, y: brickY - binH - 5, alpha: 100, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)

    // Junkbot standing (first walk-right keyframe); junkbotFrame's positioning:
    // x = e.x - frame.dx, y = e.y + e.height - 1 - h - frame.dy (RenderList.swift).
    let standFrame = junkbotAnim_walk_r[0]
    let junkbotH = spriteHeightTable[Int(standFrame.spriteID)]
    blitSprite(
      spriteID: standFrame.spriteID, x: 2 * CELL_W - standFrame.dx,
      y: brickY - 1 - junkbotH - standFrame.dy, alpha: 100,
      spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)
  }

  ps1_present_world()
  hudDrawHook?()
}
