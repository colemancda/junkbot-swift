// ports/PS1/source/main.swift — Junkbot for PlayStation 1.
//
// Uses the shared `GameEngine`/`EntityFactory`/`RenderList` from
// `Sources/JunkbotCore` directly, same as every other port -- see
// KNOWN_ISSUES.md: the root cause behind this target's Array/Dictionary
// hangs was `swift_retain`/`swift_release` needing atomic RMW instructions
// (`ll`/`sc`) that don't exist on MIPS-I; `-assume-single-threaded`
// (compile-swift.sh) fixes it, so the PS1-local GameState/FixedArray/
// PS1DynArray reimplementation that worked around it is no longer needed.
//
// `gameEngine`/`renderFrame` are locals, not globals -- see Renderer.swift's
// header comment: a *different*, still-open bug hangs on the lazy-init
// token a global with a non-trivial initializer requires, unaffected by
// -assume-single-threaded.
//
// v1 scope: a hand-built test level (8 ground bricks, a bin, Junkbot
// standing), no input/simulation yet (task #4).

@_cdecl("swift_main")
public func swiftMain() {
  ps1_init_heap()
  ps1_init_display()

  let gameEngine = GameEngine()
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

  let bot = gameEngine.makeJunkbot(x: 2 * CELL_W, y: brickY - 4 * CELL_H, facing: 1)
  gameEngine.entities.append(bot)

  gameEngine.levelBounds = LevelBounds(x: 0, y: 0, width: screenWidth, height: screenHeight)

  var renderFrame = RenderFrame()

  while true {
    ps1_begin_frame()
    renderWorld(gameEngine, into: &renderFrame)
    ps1_flip()
  }
}
