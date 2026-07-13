//---------------------------------------------------------------------------------
//
//  Junkbot for iPod Nano 2G -- Embedded Swift compiled for armv4t-none-none-eabi
//  (the Nano 2G's ARM940T), linked into a Rockbox plugin.
//
//  Like ports/iPod in celeste-swift (and unlike ports/3DS, where Swift owns
//  main()), Rockbox owns the process: plugin/junkbot.c drives the loop and
//  calls the @_cdecl entry points below. All hardware access (LCD, click wheel,
//  timing, file I/O for sprites.bin) stays on the C side; Swift owns the game
//  state (engine + level index + a click-wheel cursor + a scrolled viewport)
//  and rasterizes into the C-owned canvas.
//
//  Threading invariant: every one of these entry points runs on the plugin's
//  main thread. That is what makes the non-atomic __atomic_* stubs in
//  rockbox_shim.c correct -- never call into Swift from any other context.
//
//  Controls (mapped by junkbot.c):
//    click wheel        move cursor left/right (one stud)
//    MENU / PLAY        move cursor up / down (one brick)
//    LEFT / RIGHT       move cursor left / right (one stud)
//    SELECT             grab / drop the brick under the cursor
//    HOLD               pause menu (resume / restart / next / prev / quit)
//
//---------------------------------------------------------------------------------

import CRockbox

private let engine = GameEngine()
private var renderFrame = RenderFrame()

/// The currently-loaded level's index into `embeddedLevels` (the campaign data
/// compiled into JunkbotCore — see Generated/LevelData.swift).
private var currentLevelIndex = 0

/// World-space coordinate of the viewport's (game canvas's) top-left pixel.
private var scrollX: Int32 = 0
private var scrollY: Int32 = 0

/// The aiming reticle's world position (there is no hardware pointer on the
/// Nano 2G). Moved in grid steps; the viewport scrolls to keep it on screen.
private var cursorX: Int32 = 0
private var cursorY: Int32 = 0

/// 0 = playing, 1 = won, 2 = lost. Latched by `junkbot_tick`; the C host reads
/// it via `junkbot_winlose` to show its prompt.
private var winLoseLatch: Int32 = 0

/// Fixed-rate simulation accumulator (the engine ticks at 18Hz).
private var tickAccumulator: Int32 = 0

// MARK: - Level loading

private func clampCursorToBounds() {
  guard let b = engine.levelBounds else { return }
  cursorX = min(max(cursorX, b.x), b.x + b.width)
  cursorY = min(max(cursorY, b.y), b.y + b.height)
}

private func clampScroll() {
  guard let b = engine.levelBounds else { return }
  if b.width <= screenWidth {
    scrollX = b.x - (screenWidth - b.width) / 2
  } else {
    scrollX = min(max(scrollX, b.x), b.x + b.width - screenWidth)
  }
  if b.height <= screenHeight {
    scrollY = b.y - (screenHeight - b.height) / 2
  } else {
    scrollY = min(max(scrollY, b.y), b.y + b.height - screenHeight)
  }
}

/// Scrolls the viewport so the cursor stays within `margin` of every edge.
private func followCursor() {
  let margin: Int32 = 28
  if cursorX - scrollX < margin { scrollX = cursorX - margin }
  if cursorX - scrollX > screenWidth - margin { scrollX = cursorX - (screenWidth - margin) }
  if cursorY - scrollY < margin { scrollY = cursorY - margin }
  if cursorY - scrollY > screenHeight - margin { scrollY = cursorY - (screenHeight - margin) }
  clampScroll()
}

private func loadLevel(_ index: Int) {
  guard index >= 0, index < embeddedLevels.count else { return }
  currentLevelIndex = index
  let level = embeddedLevels[index]
  engine.loadLevelState(entities: level.makeEntities(), levelBounds: level.bounds, nextID: 0)
  engine.setBackground(
    backdropSpriteID: level.backdropSpriteID,
    backgroundDecals: level.backgroundDecals, decals: level.decals)
  winLoseLatch = 0
  tickAccumulator = 0

  // Start the cursor on Junkbot (the SDL port centers its camera there on
  // load); fall back to the level's center if the level has no Junkbot.
  var placed = false
  for e in engine.entities where e.type == .junkbot {
    cursorX = e.x + e.width / 2
    cursorY = e.y + e.height / 2
    placed = true
    break
  }
  if !placed, let b = engine.levelBounds {
    cursorX = b.x + b.width / 2
    cursorY = b.y + b.height / 2
  }
  scrollX = cursorX - screenWidth / 2
  scrollY = cursorY - screenHeight / 2
  clampScroll()
}

// MARK: - C entry points

/// One-time setup. `canvasPtr` is the C-owned 176x120 RGB565 buffer; `spritesPtr`
/// / `spritesBytes` is `sprites.bin` already loaded into the audio buffer by the
/// host. Returns 0 on success, -1 on a bad argument.
@_cdecl("junkbot_init")
public func junkbot_init(
  _ canvasPtr: UnsafeMutablePointer<UInt16>?,
  _ spritesPtr: UnsafeRawPointer?,
  _ spritesBytes: Int32
) -> Int32 {
  guard let canvasPtr, let spritesPtr,
    spritesBytes > 0
  else { return -1 }
  canvas = canvasPtr
  spritePixels = spritesPtr.assumingMemoryBound(to: UInt16.self)
  engine.initialize()
  engine.onPlaySound = { id in rb_audio_sfx(id) }
  loadLevel(0)
  return 0
}

@_cdecl("junkbot_level_count")
public func junkbot_level_count() -> Int32 { Int32(embeddedLevels.count) }

@_cdecl("junkbot_current_level")
public func junkbot_current_level() -> Int32 { Int32(currentLevelIndex) }

@_cdecl("junkbot_load_level")
public func junkbot_load_level(_ index: Int32) { loadLevel(Int(index)) }

@_cdecl("junkbot_next_level")
public func junkbot_next_level() {
  if currentLevelIndex + 1 < embeddedLevels.count { loadLevel(currentLevelIndex + 1) }
}

@_cdecl("junkbot_prev_level")
public func junkbot_prev_level() {
  if currentLevelIndex > 0 { loadLevel(currentLevelIndex - 1) }
}

@_cdecl("junkbot_restart")
public func junkbot_restart() { loadLevel(currentLevelIndex) }

/// Moves the cursor by `dx` studs / `dy` bricks (each ±1, 0), scrolls the
/// viewport to follow, and forwards the new position to the engine so an active
/// or pending grab tracks it (`mouseMove` also resolves a two-direction pending
/// grab and refreshes hover state — all no-ops when neither applies).
@_cdecl("junkbot_move_cursor")
public func junkbot_move_cursor(_ dx: Int32, _ dy: Int32) {
  cursorX += dx * CELL_W
  cursorY += dy * CELL_H
  clampCursorToBounds()
  followCursor()
  engine.mouseMove(cursorX, cursorY)
}

/// SELECT: grab the brick under the cursor, or drop the one being held. A drop
/// onto an invalid spot is refused by the engine (`canRelease`), so the grab
/// simply continues — matching the mouse ports.
@_cdecl("junkbot_toggle_grab")
public func junkbot_toggle_grab() {
  if engine.isDragging {
    engine.mouseUp(cursorX, cursorY)
  } else {
    engine.mouseDown(cursorX, cursorY)
  }
}

@_cdecl("junkbot_is_grabbing")
public func junkbot_is_grabbing() -> Int32 { engine.isDragging ? 1 : 0 }

/// Advances the simulation by the real time elapsed (`elapsedTicks` in Rockbox
/// HZ units), at the engine's fixed 18Hz. Latches win/lose the first tick it
/// resolves. Returns the win/lose latch (0/1/2).
@_cdecl("junkbot_tick")
public func junkbot_tick(_ elapsedTicks: Int32) -> Int32 {
  guard winLoseLatch == 0 else { return winLoseLatch }
  // 18 sim ticks per HZ seconds: bank 18*elapsed, spend HZ per tick.
  tickAccumulator += 18 * max(elapsedTicks, 0)
  while tickAccumulator >= 100 {  // Rockbox HZ == 100 on the Nano 2G
    tickAccumulator -= 100
    engine.tick()
    let outcome = engine.winLose()
    if outcome != 0 {
      winLoseLatch = outcome
      break
    }
  }
  return winLoseLatch
}

@_cdecl("junkbot_winlose")
public func junkbot_winlose() -> Int32 { winLoseLatch }

@_cdecl("junkbot_moves")
public func junkbot_moves() -> Int32 { engine.moves }

/// Null-terminated ASCII title/hint of the current level, for the C host's
/// intro/status text (`StaticString` literals live in static storage for the
/// program's lifetime, so returning the pointer is safe).
@_cdecl("junkbot_level_title")
public func junkbot_level_title() -> UnsafePointer<CChar>? {
  UnsafeRawPointer(embeddedLevels[currentLevelIndex].title.utf8Start)
    .assumingMemoryBound(to: CChar.self)
}

@_cdecl("junkbot_level_hint")
public func junkbot_level_hint() -> UnsafePointer<CChar>? {
  UnsafeRawPointer(embeddedLevels[currentLevelIndex].hint.utf8Start)
    .assumingMemoryBound(to: CChar.self)
}

/// Rebuilds and rasterizes the world into the canvas, then overlays the cursor.
/// C blits the canvas afterwards.
@_cdecl("junkbot_render")
public func junkbot_render() {
  // Cull to the visible viewport (plus a margin for straddling sprites) so the
  // entity sort stays cheap on a busy level — see buildRenderFrame's doc.
  let margin: Int32 = 64
  let visible = LevelBounds(
    x: scrollX - margin, y: scrollY - margin,
    width: screenWidth + margin * 2, height: screenHeight + margin * 2)
  engine.buildRenderFrame(into: &renderFrame, editing: false, visibleBounds: visible)

  canvas.update(repeating: 0, count: Int(screenWidth * screenHeight))
  for cmd in renderFrame.commands {
    switch cmd.kind {
    case .sprite: blitSprite(cmd, scrollX: scrollX, scrollY: scrollY)
    case .solidRect: fillRect(cmd, scrollX: scrollX, scrollY: scrollY)
    }
  }

  drawCursor(
    screenX: cursorX - scrollX, screenY: cursorY - scrollY, grabbing: engine.isDragging)
}
