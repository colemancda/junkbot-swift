//---------------------------------------------------------------------------------
//
//  Junkbot for Nintendo 3DS -- Embedded Swift ARM11 binary.
//
//  Same design as ports/NDS: the whole game renders on the bottom (touch)
//  screen through a scrollable viewport into the world (3DS bottom screen is
//  320x240; levels are up to ~900x675 world px). The stylus/touchscreen moves
//  bricks directly -- a touch is an engine mouseDown at that world position,
//  dragging is mouseMove, lifting is mouseUp -- with no visible cursor. The
//  D-pad (and circle pad) scrolls the viewport. The top screen is a text
//  console with the level name, hint, moves counter, and win/lose prompts.
//
//    D-pad / circle pad   scroll viewport
//    stylus / touch       grab / drag / drop bricks
//    L / R                previous / next level
//    START                restart level
//    A (or touch)          advance win/lose prompt
//
//---------------------------------------------------------------------------------

import CTRU

// MARK: - Console (top screen) helpers

func consolePrint(_ s: StaticString) {
  ctru_print_len(
    UnsafeRawPointer(s.utf8Start).assumingMemoryBound(to: CChar.self), Int32(s.utf8CodeUnitCount))
}

func consoleClearScreen() { consolePrint("\u{1b}[2J") }

// MARK: - Video / audio setup

gfxInitDefault()
gfxSetScreenFormat(GFX_BOTTOM, GSP_RGB565_OES)
consoleInit(GFX_TOP, nil)
ctru_audio_init()

// MARK: - Engine + level loading

let gameEngine = GameEngine()
gameEngine.onPlaySound = { id in playSound(id) }

var currentLevelIndex = 0
/// World-space coordinate of the viewport's (bottom screen's) top-left pixel.
var scrollX: Int32 = 0
var scrollY: Int32 = 0
/// 0 = playing, 1 = won (waiting for input), 2 = lost (waiting for input).
var winLoseLatch: Int32 = 0
var lastShownMoves: Int32 = -1
var frameDirty = true

func clampScroll() {
  guard let bounds = gameEngine.levelBounds else { return }
  if bounds.width <= screenWidth {
    scrollX = bounds.x - (screenWidth - bounds.width) / 2
  } else {
    scrollX = min(max(scrollX, bounds.x), bounds.x + bounds.width - screenWidth)
  }
  if bounds.height <= screenHeight {
    scrollY = bounds.y - (screenHeight - bounds.height) / 2
  } else {
    scrollY = min(max(scrollY, bounds.y), bounds.y + bounds.height - screenHeight)
  }
}

func drawStatusLine() {
  // Row 21, after a clear-to-end-of-line: "Moves: N (par M)".
  consolePrint("\u{1b}[21;0H\u{1b}[K Moves: ")
  ctru_printf_1i("%d", gameEngine.moves)
  let par = embeddedLevels[currentLevelIndex].par
  if par != Int32.max {
    ctru_printf_1i("  (par %d)", par)
  }
  lastShownMoves = gameEngine.moves
}

func showLevelInfo() {
  consoleClearScreen()
  consolePrint("\u{1b}[0;0H JUNKBOT  level ")
  ctru_printf_2i("%d/%d", Int32(currentLevelIndex + 1), Int32(embeddedLevels.count))
  consolePrint("\n\n ")
  consolePrint(embeddedLevels[currentLevelIndex].title)
  consolePrint("\n\n ")
  consolePrint(embeddedLevels[currentLevelIndex].hint)
  consolePrint("\u{1b}[19;0H D-pad scroll   stylus drag\n L/R level  START restart")
  drawStatusLine()
}

func loadLevel(_ index: Int) {
  currentLevelIndex = index
  // Levels are pre-parsed on the host into entity-builder code (see
  // tools/LevelDump) -- no level text exists on-device.
  let level = embeddedLevels[index]
  gameEngine.loadLevelState(
    entities: level.makeEntities(), levelBounds: level.bounds, nextID: 0)
  gameEngine.setBackground(
    backdropSpriteID: level.backdropSpriteID, backgroundDecals: [], decals: [])
  winLoseLatch = 0
  // Start the viewport centered on Junkbot (the SDL port's camera does the
  // same on load); after this, scrolling is fully manual per the port design.
  scrollX = 0
  scrollY = 0
  for entity in gameEngine.entities where entity.type == .junkbot {
    scrollX = entity.x + entity.width / 2 - screenWidth / 2
    scrollY = entity.y + entity.height / 2 - screenHeight / 2
    break
  }
  clampScroll()
  showLevelInfo()
  startRandomLevelMusic()
  frameDirty = true
}

loadLevel(0)

// MARK: - Main loop

/// Matches the game's 18Hz simulation rate against the 3DS's ~60Hz VBlank:
/// accumulate 18 sixtieths per frame, tick when a whole tick is banked.
var tickAccumulator: Int32 = 0
let scrollSpeed: Int32 = 3

var stylusDown = false
var lastTouchWorldX: Int32 = 0
var lastTouchWorldY: Int32 = 0

while aptMainLoop() {
  // gspWaitForVBlank() is a function-like macro the Clang importer can't
  // surface; call what it expands to (gspWaitForVBlank0()) directly.
  gspWaitForEvent(GSPGPU_EVENT_VBlank0, true)
  hidScanInput()
  let pressed = hidKeysDown()
  let held = hidKeysHeld()
  let released = hidKeysUp()

  // Level switching / restart.
  if pressed & KEY_L != 0, currentLevelIndex > 0 {
    loadLevel(currentLevelIndex - 1)
  }
  if pressed & KEY_R != 0, currentLevelIndex + 1 < embeddedLevels.count {
    loadLevel(currentLevelIndex + 1)
  }
  if pressed & KEY_START != 0 {
    loadLevel(currentLevelIndex)
  }

  // Win/lose prompt: A or a fresh touch advances.
  if winLoseLatch != 0 {
    if pressed & (KEY_A | KEY_TOUCH) != 0 {
      if winLoseLatch == 1, currentLevelIndex + 1 < embeddedLevels.count {
        loadLevel(currentLevelIndex + 1)
      } else {
        loadLevel(currentLevelIndex)
      }
    }
    continue
  }

  // D-pad/circle-pad viewport scroll.
  if held & (KEY_LEFT | KEY_RIGHT | KEY_UP | KEY_DOWN) != 0 {
    if held & KEY_LEFT != 0 { scrollX -= scrollSpeed }
    if held & KEY_RIGHT != 0 { scrollX += scrollSpeed }
    if held & KEY_UP != 0 { scrollY -= scrollSpeed }
    if held & KEY_DOWN != 0 { scrollY += scrollSpeed }
    clampScroll()
    frameDirty = true
  }

  // Touch -> engine mouse events, in world coordinates. No cursor is drawn;
  // the touch position IS the pointer.
  if held & KEY_TOUCH != 0 {
    var touch = touchPosition()
    hidTouchRead(&touch)
    let worldX = scrollX + Int32(touch.px)
    let worldY = scrollY + Int32(touch.py)
    if pressed & KEY_TOUCH != 0 {
      gameEngine.mouseDown(worldX, worldY)
      stylusDown = true
      frameDirty = true
    } else if stylusDown, worldX != lastTouchWorldX || worldY != lastTouchWorldY {
      gameEngine.mouseMove(worldX, worldY)
      frameDirty = true
    }
    lastTouchWorldX = worldX
    lastTouchWorldY = worldY
  }
  if released & KEY_TOUCH != 0, stylusDown {
    gameEngine.mouseUp(lastTouchWorldX, lastTouchWorldY)
    stylusDown = false
    frameDirty = true
  }

  // Fixed-rate simulation.
  tickAccumulator += 18
  if tickAccumulator >= 60 {
    tickAccumulator -= 60
    gameEngine.tick()
    frameDirty = true

    let outcome = gameEngine.winLose()
    if outcome != 0 {
      winLoseLatch = outcome
      stopMusic()
      consolePrint("\u{1b}[10;0H\u{1b}[K")
      consolePrint(
        outcome == 1
          ? "\u{1b}[10;6H*** YOU WIN! ***" : "\u{1b}[10;5H*** TRY AGAIN ***")
      consolePrint("\u{1b}[12;3Hpress A or tap to continue")
    }
    if gameEngine.moves != lastShownMoves {
      drawStatusLine()
    }
  }

  if frameDirty {
    renderWorld(scrollX: scrollX, scrollY: scrollY)
    frameDirty = false
  }
}

gfxExit()
