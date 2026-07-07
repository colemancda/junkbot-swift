import Foundation
import Testing

@testable import JunkbotCore

/// Regression coverage for a stale-acceleration-structure bug: `simulate()` reorders `entities`
/// (`entities.sort { $0.id < $1.id }`) after its last `rebuildAccelerationStructures()` call, so
/// `entitiesByTopY`/`entitiesByBottomY` end each tick holding indices from before that reorder -
/// silently pointing at the wrong entities. The very next `mouseDown`'s `findAttachedGroup`/
/// `connectsToFixed` check then mis-evaluates which bricks are independently supported, wrongly
/// pulling in bricks that should stay behind. Fully deterministic: a single `tick()` (even with
/// no entities actually moving - just hovering the mouse, which calls `tick()` every frame) is
/// enough to corrupt the very next grab. Fixed by rebuilding once more after that final sort.
@Suite("Stale acceleration structures after simulate()'s final sort")
struct PyramidBisectTests {

  static func loadTitleScreenEngine() throws -> GameEngine {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent(
        "ports/Darwin/JunkbotMobile.swiftpm/Sources/JunkbotMobile/levels/custom/Title Screen.txt")
    let text = try String(contentsOf: url, encoding: .utf8)
    let engine = GameEngine()
    engine.loadLevel(Level(text: text))
    return engine
  }

  @Test("A single tick() before mouseDown must not corrupt the next grab's attached group")
  func tickBeforeGrabDoesNotCorruptAttachedGroup() throws {
    let engine = try Self.loadTitleScreenEngine()

    // The Title Screen's blue pyramid: bottom-center (id 16), mid-left (14), mid-right (15),
    // top-center (13) - matches InputTests.swift's titleScreenPyramidRepro shape exactly.
    let top = try #require(engine.entities.firstIndex { $0.x == 195 && $0.y == 306 })

    // A single simulated frame (mouse hovering nearby calls tick() every frame even before any
    // click) is enough to reproduce the corruption - no entity needs to actually move.
    engine.tick()

    engine.mouseDown(210, 315)
    let grabbedAfterDown = engine.entities.filter { $0.grabbed }.map { $0.id }
    #expect(grabbedAfterDown == [engine.entities[top].id])

    engine.mouseMove(210, 280)
    let grabbedAfterMove = engine.entities.filter { $0.grabbed }.map { $0.id }
    #expect(
      grabbedAfterMove == [engine.entities[top].id],
      "grabbing the top of the pyramid must not pull in the independently-supported legs")
  }
}
