//---------------------------------------------------------------------------------
//
//  Junkbot for Nintendo DS -- Embedded Swift ARM9 binary.
//
//  v1 scope: the whole game renders on the bottom (touch) screen through a
//  scrollable viewport into the world (DS is 256x192; levels are up to
//  ~900x675 world px). The stylus moves bricks directly -- a touch is an
//  engine mouseDown at that world position, dragging is mouseMove, lifting is
//  mouseUp -- with no visible cursor. The D-pad scrolls the viewport. The top
//  screen is a text console with the level name, hint, moves counter, and
//  win/lose prompts.
//
//    D-pad          scroll viewport
//    stylus         grab / drag / drop bricks
//    L / R          previous / next level
//    START          restart level
//    A (or stylus)  advance win/lose prompt
//
//---------------------------------------------------------------------------------

import CNDS

// KEY_TOUCH is BIT(14) -- the function-like BIT macro isn't imported.
let KEY_TOUCH: UInt32 = 1 << 14

// MARK: - Console (top screen) helpers

func consolePrint(_ s: StaticString) {
  nds_print_len(UnsafeRawPointer(s.utf8Start).assumingMemoryBound(to: CChar.self),
    Int32(s.utf8CodeUnitCount))
}

func consoleClearScreen() { consolePrint("\u{1b}[2J") }

// MARK: - Video setup
//
// Main engine: MODE_5 bitmap BG on the bottom LCD, double-buffered by
// flipping the bitmap base between the two halves of VRAM A+B (the
// double_buffer libnds example's setup). Sub engine: the demo console, which
// lands on the top LCD because of lcdMainOnBottom().

videoSetMode(MODE_5_2D.rawValue)
lcdMainOnBottom()
vramSetPrimaryBanks(
  VRAM_A_MAIN_BG_0x06000000, VRAM_B_MAIN_BG_0x06020000,
  VRAM_C_SUB_BG, VRAM_D_LCD)
consoleDemoInit()

let bg = bgInit(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0)
/// The buffer currently being drawn into (the one NOT displayed).
var backBuffer = bgGetGfxPtr(bg)! + 256 * 256

func flipBuffers() {
  backBuffer = bgGetGfxPtr(bg)!
  // Each map base is 16KB; a 256x256x16bpp screen is 128KB = 8 bases.
  bgSetMapBase(bg, bgGetMapBase(bg) == 8 ? 0 : 8)
}

// MARK: - Audio

soundEnable()

// MARK: - Engine + level loading

let gameEngine = GameEngine()
gameEngine.onPlaySound = { id in playSound(id) }

var currentLevelIndex = 0
/// World-space coordinate of the viewport's (top screen's) top-left pixel.
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
  nds_printf_1i("%d", gameEngine.moves)
  let par = embeddedLevels[currentLevelIndex].par
  if par != Int32.max {
    nds_printf_1i("  (par %d)", par)
  }
  lastShownMoves = gameEngine.moves
}

func showLevelInfo() {
  consoleClearScreen()
  consolePrint("\u{1b}[0;0H JUNKBOT  level ")
  nds_printf_2i("%d/%d", Int32(currentLevelIndex + 1), Int32(embeddedLevels.count))
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
  frameDirty = true
}

loadLevel(0)

// MARK: - Main loop

/// Matches the game's 18Hz simulation rate against the DS's ~60Hz VBlank:
/// accumulate 18 sixtieths per frame, tick when a whole tick is banked.
var tickAccumulator: Int32 = 0
let scrollSpeed: Int32 = 3

var stylusDown = false
var lastTouchWorldX: Int32 = 0
var lastTouchWorldY: Int32 = 0

while pmMainLoop() {
  threadWaitForVBlank()
  scanKeys()
  let pressed = keysDown()
  let held = keysHeld()
  let released = keysUp()

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

  // Win/lose prompt: A or a fresh stylus tap advances.
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

  // D-pad viewport scroll.
  if held & (KEY_LEFT | KEY_RIGHT | KEY_UP | KEY_DOWN) != 0 {
    if held & KEY_LEFT != 0 { scrollX -= scrollSpeed }
    if held & KEY_RIGHT != 0 { scrollX += scrollSpeed }
    if held & KEY_UP != 0 { scrollY -= scrollSpeed }
    if held & KEY_DOWN != 0 { scrollY += scrollSpeed }
    clampScroll()
    frameDirty = true
  }

  // Stylus -> engine mouse events, in world coordinates. No cursor is drawn;
  // the stylus position IS the pointer.
  if held & KEY_TOUCH != 0 {
    var touch = touchPosition()
    touchRead(&touch)
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
    renderWorld(into: backBuffer, scrollX: scrollX, scrollY: scrollY)
    flipBuffers()
    frameDirty = false
  }
}
