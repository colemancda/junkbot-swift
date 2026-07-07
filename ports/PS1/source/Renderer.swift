// ports/PS1/source/Renderer.swift — software rasterizer for the PS1's single
// 320x240 screen, using the shared `GameEngine`/`RenderList`/`RenderCommand`
// pipeline (see KNOWN_ISSUES.md: the root cause behind every earlier
// Array/Dictionary "codegen bug" on this target was `swift_retain`/
// `swift_release` compiling to atomic RMW instructions the R3000A's MIPS-I
// core doesn't support -- `-assume-single-threaded` (compile-swift.sh) fixes
// it, so this port no longer needs a PS1-local GameState/FixedArray
// reimplementation; it uses the same JunkbotCore every other port does).
//
// `renderFrame`/`spritePixels` are passed in as `inout`/computed locally
// rather than being top-level globals: a *different*, still-open bug (see
// KNOWN_ISSUES.md "Update 5") hangs on the lazy-init token (`swift_once`) a
// global with a non-trivial initializer requires -- unaffected by
// -assume-single-threaded, which only touches retain/release, not
// once-token codegen. Locals sidestep it entirely.
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
  _ cmd: RenderCommand, spritePixels: UnsafePointer<UInt8>,
  into buffer: UnsafeMutablePointer<UInt16>, strideElements: Int32,
  palette: UnsafePointer<UInt16>
) {
  let id = Int(cmd.spriteID)
  guard id >= 0, id < spriteDataOffsetTable.count else { return }
  let offset = spriteDataOffsetTable[id]
  guard offset >= 0 else { return }

  let spriteW = spriteWidthTable[id]
  let spriteH = spriteHeightTable[id]
  let visibleW = cmd.c > 0 ? min(spriteW, cmd.c) : spriteW

  let x0 = max(0, cmd.x), y0 = max(0, cmd.y)
  let x1 = min(screenWidth, cmd.x &+ visibleW)
  let y1 = min(screenHeight, cmd.y &+ spriteH)
  guard x0 < x1, y0 < y1 else { return }

  let alpha = cmd.a
  let src = spritePixels + Int(offset)
  var dy = y0
  while dy < y1 {
    let srcRow = src + Int(dy &- cmd.y) * Int(spriteW)
    let dstRow = buffer + Int(dy) * Int(strideElements)
    var dx = x0
    while dx < x1 {
      let index = srcRow[Int(dx &- cmd.x)]
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
  _ cmd: RenderCommand, into buffer: UnsafeMutablePointer<UInt16>, strideElements: Int32
) {
  let rgba = UInt32(bitPattern: cmd.c)
  let alpha = Int32((rgba & 0xFF) &* 100 / 255)
  guard alpha > 0 else { return }
  let r = UInt16((rgba >> 27) & 0x1F)
  let g5 = UInt16((rgba >> 19) & 0x1F)
  let b = UInt16((rgba >> 11) & 0x1F)
  let color = packPS1(fromBGR555: 0x8000 | (b << 10) | (g5 << 5) | r)

  let x0 = max(0, cmd.x), y0 = max(0, cmd.y)
  let x1 = min(screenWidth, cmd.x &+ cmd.a)
  let y1 = min(screenHeight, cmd.y &+ cmd.b)
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

/// Set by main.swift: draws HUD overlay text via ps1_draw_text/FntSort,
/// called after the world raster has been handed to the GPU.
var hudDrawHook: (() -> Void)?

/// Set by main.swift: draws directly into the world's RAM framebuffer
/// (e.g. `drawCursor`) -- must run before `ps1_present_world()` uploads it,
/// unlike `hudDrawHook`, which draws through the GPU ordering table instead
/// and only needs to run before the next `ps1_flip()`.
var worldOverlayHook: (() -> Void)?

/// A small crosshair at the cursor's screen position, matching
/// ports/N64/source/Renderer.swift's `drawCursor` -- there's no touchscreen
/// on this target either, so the player needs to see where the D-pad-driven
/// virtual cursor is. Call after `renderWorld` (writes directly into the
/// world framebuffer) and before `ps1_flip`.
func drawCursor(x: Int32, y: Int32, down: Bool) {
  let buffer = ps1_world_framebuffer()!
  let strideElements: Int32 = screenWidth
  // BGR555: red while dragging, yellow otherwise.
  let color: UInt16 = down ? packPS1(fromBGR555: (4 << 10) | (4 << 5) | 31) : packPS1(fromBGR555: (4 << 10) | (31 << 5) | 31)
  var d: Int32 = -4
  while d <= 4 {
    let px = x + d, py = y + d
    if px >= 0, px < screenWidth, y >= 0, y < screenHeight {
      buffer[Int(y) * Int(strideElements) + Int(px)] = color
    }
    if py >= 0, py < screenHeight, x >= 0, x < screenWidth {
      buffer[Int(py) * Int(strideElements) + Int(x)] = color
    }
    d += 1
  }
}

/// Rebuilds `gameEngine`'s command list into `renderFrame` and rasterizes it
/// into the RAM framebuffer, then presents it. No viewport scrolling yet
/// (task #4 -- input/camera); the hand-built test level fits on one screen.
func renderWorld(_ gameEngine: GameEngine, into renderFrame: inout RenderFrame) {
  gameEngine.buildRenderFrame(into: &renderFrame, editing: false)

  // Computed locally every call -- see this file's header comment for why
  // (a global `let` with this exact initializer expression hangs on this
  // target; the same expression as a local works fine).
  let spritePixels: UnsafePointer<UInt8> =
    UnsafeRawPointer(ps1_asset_sprites_bin()!).assumingMemoryBound(to: UInt8.self)

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
        blitSprite(cmd, spritePixels: spritePixels, into: buffer, strideElements: strideElements, palette: palette)
      case .solidRect:
        fillRect(cmd, into: buffer, strideElements: strideElements)
      }
      index += 1
    }
  }

  worldOverlayHook?()

  ps1_present_world()
  hudDrawHook?()
}
