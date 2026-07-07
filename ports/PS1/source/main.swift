// ports/PS1/source/main.swift — Junkbot for PlayStation 1.
//
// Uses the shared `GameEngine`/`EntityFactory`/`RenderList` from
// `Sources/JunkbotCore` directly, same as every other port -- see
// KNOWN_ISSUES.md: the root cause behind this target's Array/Dictionary
// hangs was `swift_retain`/`swift_release` needing atomic RMW instructions
// (`ll`/`sc`) that don't exist on MIPS-I; `-assume-single-threaded` plus
// `Support/fix_atomics.py` (compile-swift.sh) fixes it, so the PS1-local
// GameState/FixedArray/PS1DynArray reimplementation that worked around it
// is no longer needed.
//
// `gameEngine`/`renderFrame` are locals, not globals -- see Renderer.swift's
// header comment: a *different*, still-open bug hangs on the lazy-init
// token a global with a non-trivial initializer requires, unaffected by
// -assume-single-threaded.
//
// Input: no touchscreen or analog stick assumed (base digital pad only,
// matching ports/N64's D-pad fallback) -- the D-pad drives a virtual
// world-space cursor (nudged one grid cell per press, with software
// auto-repeat while held), Cross grabs/drops at the cursor via
// `GameEngine`'s `mouseDown`/`mouseMove`/`mouseUp` (the same entry points
// every other port's pointer/touch input funnels through), and Start
// restarts the level. See common/shim.c's `ps1_init_pad`/`ps1_pad_held`.
//
// v1 scope: a hand-built test level (8 ground bricks, a bin, Junkbot
// standing).

// Bit positions from psxpad.h's `PadButton` (hardcoded rather than relying
// on the C enum's Swift import, matching ports/N64/source/main.swift's own
// BTN_* constants).
let PAD_START: UInt16 = 1 << 3
let PAD_UP: UInt16 = 1 << 4
let PAD_RIGHT: UInt16 = 1 << 5
let PAD_DOWN: UInt16 = 1 << 6
let PAD_LEFT: UInt16 = 1 << 7
let PAD_CROSS: UInt16 = 1 << 14

func buildTestLevel(_ gameEngine: GameEngine) -> (cursorX: Int32, cursorY: Int32) {
  gameEngine.resetLevel()

  let brickY: Int32 = 10 * CELL_H
  let colors: [Int32] = [0, 1, 2, 3, 4, 0, 1, 2]
  for i in 0..<8 {
    let e = gameEngine.makeBrick(
      x: Int32(i) * 8 * CELL_W, y: brickY, widthInStuds: 8, colorIndex: colors[i], fixed: true)
    gameEngine.entities.append(e)
  }

  let bin = gameEngine.makeBin(x: 50 * CELL_W, y: brickY - 3 * CELL_H)
  gameEngine.entities.append(bin)

  let botX: Int32 = 2 * CELL_W
  let botY: Int32 = brickY - 4 * CELL_H
  let bot = gameEngine.makeJunkbot(x: botX, y: botY, facing: 1)
  gameEngine.entities.append(bot)

  gameEngine.levelBounds = LevelBounds(x: 0, y: 0, width: screenWidth, height: screenHeight)
  return (botX + CELL_W, botY + CELL_H)
}

@_cdecl("swift_main")
public func swiftMain() {
  ps1_init_heap()
  ps1_init_display()
  ps1_init_pad()

  let gameEngine = GameEngine()
  var (cursorX, cursorY) = buildTestLevel(gameEngine)
  var cursorDown = false

  var renderFrame = RenderFrame()
  worldOverlayHook = { drawCursor(x: cursorX, y: cursorY, down: cursorDown) }

  var previousHeld: UInt16 = 0
  // Frames-held counters per D-pad direction, for a simple press-then-repeat
  // cadence (immediate nudge on press, then every `repeatDelay` frames).
  var heldFramesUp = 0, heldFramesDown = 0, heldFramesLeft = 0, heldFramesRight = 0
  let repeatDelay = 10

  @inline(__always)
  func nudgeIfDue(_ isHeld: Bool, _ frames: inout Int, _ apply: () -> Void) {
    guard isHeld else { frames = 0; return }
    if frames == 0 || frames >= repeatDelay {
      apply()
      frames = frames >= repeatDelay ? 1 : frames + 1
    } else {
      frames += 1
    }
  }

  var tickAccumulator: Int32 = 0

  while true {
    ps1_begin_frame()

    let held = ps1_pad_held()
    let pressed = held & ~previousHeld
    previousHeld = held

    if pressed & PAD_START != 0 {
      (cursorX, cursorY) = buildTestLevel(gameEngine)
      cursorDown = false
    }

    nudgeIfDue(held & PAD_UP != 0, &heldFramesUp) { cursorY -= CELL_H }
    nudgeIfDue(held & PAD_DOWN != 0, &heldFramesDown) { cursorY += CELL_H }
    nudgeIfDue(held & PAD_LEFT != 0, &heldFramesLeft) { cursorX -= CELL_W }
    nudgeIfDue(held & PAD_RIGHT != 0, &heldFramesRight) { cursorX += CELL_W }

    let crossDown = held & PAD_CROSS != 0
    if pressed & PAD_CROSS != 0 {
      gameEngine.mouseDown(cursorX, cursorY)
      cursorDown = true
    } else if crossDown, cursorDown {
      gameEngine.mouseMove(cursorX, cursorY)
    }
    if !crossDown, cursorDown {
      gameEngine.mouseUp(cursorX, cursorY)
      cursorDown = false
    }

    // Matches ports/N64: 18Hz simulation rate against a 60Hz frame rate.
    tickAccumulator += 18
    if tickAccumulator >= 60 {
      tickAccumulator -= 60
      gameEngine.tick()
    }

    renderWorld(gameEngine, into: &renderFrame)
    ps1_flip()
  }
}
