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

// MARK: - Video setup
//
// Both engines run MODE_5 bitmap BGs: the main engine double-buffered (flipping
// between the two halves of VRAM A+B, the double_buffer libnds example's
// setup) for the bottom/touch screen's 60Hz world redraws, the sub engine
// single-buffered (redrawn in place, on demand - see TextRenderer.swift) for
// the top screen's info panel, which only changes on a level load or a moves-
// counter/win-lose update. lcdMainOnBottom() puts the main engine's output on
// the bottom (touch) LCD and the sub engine's on top.

videoSetMode(MODE_5_2D.rawValue)
videoSetModeSub(MODE_5_2D.rawValue)
lcdMainOnBottom()
vramSetPrimaryBanks(
  VRAM_A_MAIN_BG_0x06000000, VRAM_B_MAIN_BG_0x06020000,
  VRAM_C_SUB_BG, VRAM_D_LCD)

let bg = bgInit(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0)
/// The buffer currently being drawn into (the one NOT displayed).
var backBuffer = bgGetGfxPtr(bg)! + 256 * 256

func flipBuffers() {
  backBuffer = bgGetGfxPtr(bg)!
  // Each map base is 16KB; a 256x256x16bpp screen is 128KB = 8 bases.
  bgSetMapBase(bg, bgGetMapBase(bg) == 8 ? 0 : 8)
}

let topBg = bgInitSub(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0)
let topBuffer = bgGetGfxPtr(topBg)!

func clearTopScreen() {
  dmaFillHalfWords(topScreenBackgroundColor, topBuffer, UInt32(screenWidth * screenHeight) * 2)
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

/// Fixed screen regions redrawn independently: the header (level title, changes only on load)
/// stays untouched while the moves counter updates every tick it changes.
let statusLineY: Int32 = 170

func drawStatusLine() {
  clearRect(x: 0, y: statusLineY, width: screenWidth, height: fontGlyphHeight + 3, into: topBuffer)
  var x = drawText(
    " Moves: ", x: 6, y: statusLineY, scale: 1, color: topScreenTextColor, into: topBuffer)
  x = drawInt(gameEngine.moves, x: x, y: statusLineY, scale: 1, color: topScreenTextColor, into: topBuffer)
  let par = embeddedLevels[currentLevelIndex].par
  if par != Int32.max {
    x = drawText(
      "  (par ", x: x, y: statusLineY, scale: 1, color: topScreenTextColor, into: topBuffer)
    x = drawInt(par, x: x, y: statusLineY, scale: 1, color: topScreenTextColor, into: topBuffer)
    drawText(")", x: x, y: statusLineY, scale: 1, color: topScreenTextColor, into: topBuffer)
  }
  lastShownMoves = gameEngine.moves
}

func showLevelInfo() {
  clearTopScreen()
  var x = drawText(
    " JUNKBOT  LEVEL ", x: 6, y: 6, scale: 2, color: topScreenTextColor, into: topBuffer)
  x = drawInt(
    Int32(currentLevelIndex + 1), x: x, y: 6, scale: 2, color: topScreenTextColor, into: topBuffer)
  x = drawText("/", x: x, y: 6, scale: 2, color: topScreenTextColor, into: topBuffer)
  drawInt(
    Int32(embeddedLevels.count), x: x, y: 6, scale: 2, color: topScreenTextColor, into: topBuffer)

  let afterTitle = drawWrappedText(
    embeddedLevels[currentLevelIndex].title, x: 6, y: 26, maxWidth: screenWidth - 12, scale: 2,
    color: topScreenTextColor, into: topBuffer)
  drawWrappedText(
    embeddedLevels[currentLevelIndex].hint, x: 6, y: afterTitle + 6, maxWidth: screenWidth - 12,
    scale: 1, color: topScreenTextColor, into: topBuffer)

  drawText(
    "D-PAD SCROLL  STYLUS DRAG", x: 6, y: 148, scale: 1, color: topScreenTextColor,
    into: topBuffer)
  drawText(
    "L/R LEVEL  START RESTART", x: 6, y: 158, scale: 1, color: topScreenTextColor,
    into: topBuffer)
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
      stopMusic()
      clearRect(x: 0, y: 82, width: screenWidth, height: 44, into: topBuffer)
      drawText(
        outcome == 1 ? " *** YOU WIN! ***" : " *** TRY AGAIN ***", x: 6, y: 84, scale: 2,
        color: topScreenTextColor, into: topBuffer)
      drawText(
        "press A or tap to continue", x: 6, y: 108, scale: 1, color: topScreenTextColor,
        into: topBuffer)
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
