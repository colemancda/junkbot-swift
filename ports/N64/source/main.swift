//---------------------------------------------------------------------------------
//
//  Junkbot for Nintendo 64 -- Embedded Swift VR4300 (MIPS III) binary, built
//  against the open-source libdragon SDK.
//
//  v1 scope: the whole game renders on the N64's single 320x240 screen through
//  a scrollable viewport into the world (levels are up to ~900x675 world px),
//  with a HUD strip (level number, moves counter, win/lose prompt) drawn
//  directly over the world every frame (see source/TextRenderer.swift) -- the
//  N64 has no second screen/touch input like ports/3DS/ports/NDS, so there's
//  no separate console surface. The analog stick drives a virtual cursor for
//  grab/drag/drop (an on-screen crosshair, since -- unlike a touchscreen --
//  the player can't see where their finger is); the C buttons scroll the
//  viewport; the D-pad also drives the cursor, but by exactly one stud
//  (CELL_W/CELL_H) per press, for placements the analog stick can't land
//  precisely on.
//
//    control stick   move the cursor
//    D-pad           move the cursor by one stud (precise nudge)
//    A               grab / drop at the cursor
//    C buttons       scroll viewport
//    L / R           previous / next level
//    START           restart level
//
//---------------------------------------------------------------------------------

import CN64

// Bit layout of n64_buttons_held/pressed/released (see common/shim.h).
let BTN_A: UInt32 = 1 << 0
let BTN_START: UInt32 = 1 << 3
let BTN_D_UP: UInt32 = 1 << 4
let BTN_D_DOWN: UInt32 = 1 << 5
let BTN_D_LEFT: UInt32 = 1 << 6
let BTN_D_RIGHT: UInt32 = 1 << 7
let BTN_L: UInt32 = 1 << 10
let BTN_R: UInt32 = 1 << 11
let BTN_C_UP: UInt32 = 1 << 12
let BTN_C_DOWN: UInt32 = 1 << 13
let BTN_C_LEFT: UInt32 = 1 << 14
let BTN_C_RIGHT: UInt32 = 1 << 15

n64_init()

// MARK: - Engine + level loading

let gameEngine = GameEngine()
gameEngine.onPlaySound = { id in playSound(id) }

/// `junkbotCampaignLevels` (`Sources/JunkbotCore/Generated/JunkbotLevelData.swift`, shared with
/// every port) - this v1 port only ships the base Junkbot campaign (Undercover Exclusive is
/// untested here), so it excludes `UndercoverLevelData.swift`/`LevelData.swift` entirely (see
/// compile-swift.sh's GENERATED_EXCLUDE) rather than filter a combined array containing both at
/// runtime - unlike an unreferenced top-level declaration, entries that are merely unused
/// *within* an array this port does reference can't be stripped.
let junkbotLevels = junkbotCampaignLevels

var currentLevelIndex = 0
/// World-space coordinate of the viewport's top-left pixel.
var scrollX: Int32 = 0
var scrollY: Int32 = 0
/// World-space position of the stick-driven virtual cursor.
var cursorX: Int32 = 0
var cursorY: Int32 = 0
var cursorDown = false
/// 0 = playing, 1 = won (waiting for input), 2 = lost (waiting for input).
var winLoseLatch: Int32 = 0

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

/// A small crosshair at the cursor's screen position -- unlike a touchscreen,
/// there's nothing else showing the player where the stick-driven cursor is.
func drawCursor(into buffer: UnsafeMutablePointer<UInt16>, strideElements: Int32) {
  let cx = cursorX - scrollX
  let cy = cursorY - scrollY
  // BGR555: red (R=31 G=4 B=4) while dragging, yellow (R=31 G=31 B=4) otherwise.
  let color: UInt16 = cursorDown ? packRGBA5551(fromBGR555: (4 << 10) | (4 << 5) | 31) : packRGBA5551(fromBGR555: (4 << 10) | (31 << 5) | 31)
  var d: Int32 = -4
  while d <= 4 {
    let px = cx + d, py = cy + d
    if px >= 0, px < screenWidth, cy >= 0, cy < screenHeight {
      buffer[Int(cy) * Int(strideElements) + Int(px)] = color
    }
    if py >= 0, py < screenHeight, cx >= 0, cx < screenWidth {
      buffer[Int(py) * Int(strideElements) + Int(cx)] = color
    }
    d += 1
  }
}

func drawHUD(into buffer: UnsafeMutablePointer<UInt16>, strideElements: Int32) {
  drawCursor(into: buffer, strideElements: strideElements)
  clearRect(x: 0, y: 0, width: screenWidth, height: fontGlyphHeight + 5, strideElements: strideElements, into: buffer)
  var x = drawText(" LVL ", x: 2, y: 2, scale: 1, color: hudTextColor, strideElements: strideElements, into: buffer)
  x = drawInt(Int32(currentLevelIndex + 1), x: x, y: 2, scale: 1, color: hudTextColor, strideElements: strideElements, into: buffer)
  x = drawText("/", x: x, y: 2, scale: 1, color: hudTextColor, strideElements: strideElements, into: buffer)
  x = drawInt(Int32(junkbotLevels.count), x: x, y: 2, scale: 1, color: hudTextColor, strideElements: strideElements, into: buffer)
  x = drawText("  MOVES ", x: x, y: 2, scale: 1, color: hudTextColor, strideElements: strideElements, into: buffer)
  drawInt(gameEngine.moves, x: x, y: 2, scale: 1, color: hudTextColor, strideElements: strideElements, into: buffer)

  if winLoseLatch != 0 {
    clearRect(x: 40, y: 100, width: screenWidth - 80, height: 40, strideElements: strideElements, into: buffer)
    drawText(
      winLoseLatch == 1 ? " *** YOU WIN! ***" : " *** TRY AGAIN ***", x: 48, y: 108, scale: 2,
      color: hudTextColor, strideElements: strideElements, into: buffer)
    drawText(
      "press A to continue", x: 48, y: 124, scale: 1, color: hudTextColor,
      strideElements: strideElements, into: buffer)
  }
}
hudDrawHook = drawHUD(into:strideElements:)

func loadLevel(_ index: Int) {
  currentLevelIndex = index
  // Levels are pre-parsed on the host into entity-builder code (see
  // Sources/JunkbotCore/Generated/JunkbotLevelData.swift, produced by the
  // repo root's `make codegen`) -- no level text exists on-device.
  let level = junkbotLevels[index]
  gameEngine.loadLevelState(
    entities: level.makeEntities(), levelBounds: level.bounds, nextID: 0)
  gameEngine.setBackground(
    backdropSpriteID: level.backdropSpriteID, backgroundDecals: [], decals: [])
  winLoseLatch = 0
  // Start the viewport (and cursor) centered on Junkbot.
  scrollX = 0
  scrollY = 0
  for entity in gameEngine.entities where entity.type == .junkbot {
    scrollX = entity.x + entity.width / 2 - screenWidth / 2
    scrollY = entity.y + entity.height / 2 - screenHeight / 2
    break
  }
  clampScroll()
  cursorX = scrollX + screenWidth / 2
  cursorY = scrollY + screenHeight / 2
  startRandomLevelMusic()
}

loadLevel(0)

// MARK: - Main loop

/// Matches the game's 18Hz simulation rate against the N64's ~60Hz VI refresh:
/// accumulate 18 sixtieths per frame, tick when a whole tick is banked.
var tickAccumulator: Int32 = 0
let scrollSpeed: Int32 = 3
/// Stick range is roughly (-85, +85) on OEM hardware; >>4 gives a ~5px/frame
/// top cursor speed, plenty precise for this game's 15x18px grid.
let cursorStickShift: Int32 = 4

while true {
  let held = n64_buttons_held()
  let pressed = n64_buttons_pressed()

  // Level switching / restart.
  if pressed & BTN_L != 0, currentLevelIndex > 0 {
    loadLevel(currentLevelIndex - 1)
  }
  if pressed & BTN_R != 0, currentLevelIndex + 1 < junkbotLevels.count {
    loadLevel(currentLevelIndex + 1)
  }
  if pressed & BTN_START != 0 {
    loadLevel(currentLevelIndex)
  }

  // Win/lose prompt: A advances.
  if winLoseLatch != 0 {
    if pressed & BTN_A != 0 {
      if winLoseLatch == 1, currentLevelIndex + 1 < junkbotLevels.count {
        loadLevel(currentLevelIndex + 1)
      } else {
        loadLevel(currentLevelIndex)
      }
    }
    renderWorld(scrollX: scrollX, scrollY: scrollY)
    pumpAudio()
    continue
  }

  // C buttons -> viewport scroll.
  if held & BTN_C_LEFT != 0 { scrollX -= scrollSpeed }
  if held & BTN_C_RIGHT != 0 { scrollX += scrollSpeed }
  if held & BTN_C_UP != 0 { scrollY -= scrollSpeed }
  if held & BTN_C_DOWN != 0 { scrollY += scrollSpeed }
  clampScroll()

  // Stick -> virtual cursor, in world coordinates.
  var stickX: Int32 = 0
  var stickY: Int32 = 0
  n64_stick(&stickX, &stickY)
  cursorX += stickX >> cursorStickShift
  cursorY -= stickY >> cursorStickShift  // stick_y is positive-up

  // D-pad -> cursor, nudged by exactly one stud per press (edge-triggered,
  // not held/repeating) -- a precise complement to the stick's continuous
  // analog movement, for landing a brick exactly on a grid cell.
  if pressed & BTN_D_LEFT != 0 { cursorX -= CELL_W }
  if pressed & BTN_D_RIGHT != 0 { cursorX += CELL_W }
  if pressed & BTN_D_UP != 0 { cursorY -= CELL_H }
  if pressed & BTN_D_DOWN != 0 { cursorY += CELL_H }

  // A -> engine mouse events, at the cursor's world position.
  if pressed & BTN_A != 0 {
    gameEngine.mouseDown(cursorX, cursorY)
    cursorDown = true
  } else if held & BTN_A != 0, cursorDown {
    gameEngine.mouseMove(cursorX, cursorY)
  }
  if held & BTN_A == 0, cursorDown {
    gameEngine.mouseUp(cursorX, cursorY)
    cursorDown = false
  }

  // Fixed-rate simulation.
  tickAccumulator += 18
  if tickAccumulator >= 60 {
    tickAccumulator -= 60
    gameEngine.tick()

    let outcome = gameEngine.winLose()
    if outcome != 0 {
      winLoseLatch = outcome
      stopMusic()
    }
  }

  renderWorld(scrollX: scrollX, scrollY: scrollY)
  pumpAudio()
}
