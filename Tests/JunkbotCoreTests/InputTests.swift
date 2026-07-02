import Testing

@testable import JunkbotCore

@Suite("Play-mode drag input")
struct InputTests {

  /// A fixed floor brick spanning most of the level, for things to rest on.
  static func makeFloor(_ engine: GameEngine, y: Int32) {
    engine.addBrick(0, y, 20, 0, true)
  }

  @Test("Reproduces the title-screen pyramid: grabbing the top brick should not pull in bricks below that are independently supported by adjacent fixed bricks")
  func titleScreenPyramidRepro() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 600, 600)
    // Fixed neighbors flanking the bottom brick (matches ids 21 and 20 from Title Screen.txt).
    engine.addBrick(165, 342, 2, 5, true)  // fixed, x:[165,195)
    engine.addBrick(225, 342, 2, 5, true)  // fixed, x:[225,255)
    // The 4-brick pyramid itself (matches ids 16,14,15,13 from Title Screen.txt exactly).
    engine.addBrick(195, 342, 2, 3, false)  // 16: bottom-center
    engine.addBrick(180, 324, 2, 3, false)  // 14: mid-left, partially resting on the fixed brick at x:165
    engine.addBrick(210, 324, 2, 3, false)  // 15: mid-right, partially resting on the fixed brick at x:225
    engine.addBrick(195, 306, 2, 3, false)  // 13: top-center, bridging 14 and 15
    engine.finishLoadLevel()

    func index(x: Int32, y: Int32) -> Int {
      engine.entities.firstIndex { $0.x == x && $0.y == y }!
    }
    let i16 = index(x: 195, y: 342)
    let i14 = index(x: 180, y: 324)
    let i15 = index(x: 210, y: 324)
    let i13 = index(x: 195, y: 306)

    let grabs13 = engine.possibleGrabsInDirections(startIndex: i13)
    #expect(grabs13.canGrabUpward)
    #expect(grabs13.grabUpward == [i13], "grabbing the top brick upward should only grab itself, nothing is above it")
    #expect(
      Bool(false),
      "DEBUG i13=\(i13) i14=\(i14) i15=\(i15) i16=\(i16) canGrabDownward=\(grabs13.canGrabDownward) grabDownward=\(grabs13.grabDownward)"
    )
  }

  @Test("Grabbing the middle of a stack resting on a fixed floor only allows the upward direction")
  func middleOfStackOnlyGrabsUpward() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    Self.makeFloor(engine, y: 36)  // fixed floor brick, top edge at y=36
    engine.addBrick(0, 18, 1, 0, false)  // A: middle brick, resting on the floor
    engine.addBrick(0, 0, 1, 0, false)  // B: top brick, resting on A
    engine.finishLoadLevel()

    let aIndex = engine.entities.firstIndex { $0.x == 0 && $0.y == 18 }!
    let grabs = engine.possibleGrabsInDirections(startIndex: aIndex)

    #expect(!grabs.canGrabDownward, "grabbing downward from the middle brick would drag the fixed floor")
    #expect(grabs.canGrabUpward)
    #expect(Set(grabs.grabUpward) == Set(engine.entities.indices.filter { engine.entities[$0].y <= 18 }))
  }

  @Test("Grabbing the top of a stack resting on a fixed floor should NOT pull in the independently-supported brick underneath")
  func topOfStackDoesNotPullInSupportedBrickBelow() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    Self.makeFloor(engine, y: 54)  // fixed floor, top edge at y=54
    engine.addBrick(0, 36, 1, 0, false)  // A: resting directly on the floor
    engine.addBrick(0, 18, 1, 0, false)  // B: resting on A
    engine.finishLoadLevel()

    let aIndex = engine.entities.firstIndex { $0.x == 0 && $0.y == 36 }!
    let bIndex = engine.entities.firstIndex { $0.x == 0 && $0.y == 18 }!
    let grabs = engine.possibleGrabsInDirections(startIndex: bIndex)

    #expect(grabs.canGrabUpward)
    #expect(grabs.grabUpward == [bIndex], "grabbing B upward should only grab B, not A (A is independently supported by the floor)")
    #expect(!grabs.canGrabDownward, "grabbing downward from B would drag the fixed floor (through A)")
    _ = aIndex
  }

  @Test("Grabbing a brick with unconnected bricks both above and below is ambiguous until the drag resolves")
  func ambiguousDirectionPendsUntilResolved() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    engine.addBrick(0, 0, 1, 0, false)  // C
    engine.addBrick(0, -18, 1, 0, false)  // D, directly above C; nothing below C
    engine.finishLoadLevel()

    let cIndex = engine.entities.firstIndex { $0.x == 0 && $0.y == 0 }!
    let dIndex = engine.entities.firstIndex { $0.x == 0 && $0.y == -18 }!
    let cEntity = engine.entities[cIndex]

    // Since neither C nor D is anchored to anything fixed, both grab directions succeed and (via
    // the dependent-neighbor sweep) end up pulling in the same floating pair either way - but it's
    // still ambiguous up front (mouseDown can't yet know both will match), so it must still defer
    // to mouseMove's drag-gesture resolution rather than assuming and dragging immediately.
    engine.mouseDown(cEntity.x + 1, cEntity.y + 1)
    #expect(engine.draggingIndices.isEmpty, "should not commit to a direction immediately")
    #expect(engine.pendingGrabDownward != nil)
    #expect(engine.pendingGrabUpward != nil)

    engine.mouseMove(cEntity.x + 1, cEntity.y + 1 + engine.dragResolveThreshold + 1)
    #expect(Set(engine.draggingIndices) == Set([cIndex, dIndex]))
    #expect(engine.pendingGrabDownward == nil && engine.pendingGrabUpward == nil)
  }

  @Test("canRelease rejects a position adjacent to a fire hazard even if otherwise well-supported")
  func releaseRejectedNearFire() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    Self.makeFloor(engine, y: 18)  // fixed floor, top edge at y=18
    engine.addBrick(0, 0, 1, 0, false)  // draggable brick resting on the floor
    engine.addFire(0, -18, true, -1)  // fire directly above the brick (touching, not overlapping)

    let brickIndex = engine.entities.firstIndex { $0.type == .brick && !$0.fixed }!
    engine.draggingIndices = [brickIndex]
    engine.entities[brickIndex].grabbed = true
    engine.finishLoadLevel()

    #expect(!engine.canRelease(), "adjacency to a fire hazard should block release regardless of support")
  }

  @Test("A full mouseDown/mouseMove/mouseUp cycle drags and releases onto a fixed floor")
  func fullDragCycleReleasesOntoFloor() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    Self.makeFloor(engine, y: 36)
    engine.addBrick(60, 0, 1, 0, false)  // starts unsupported, off to the side
    engine.finishLoadLevel()

    let brickIndex = engine.entities.firstIndex { $0.type == .brick && !$0.fixed }!
    let brick = engine.entities[brickIndex]

    // An isolated brick (nothing touching it in any direction) is still ambiguous at press time
    // (both directions trivially succeed with just itself) - matches JS, which defers even this
    // case to the drag gesture before actually starting the drag.
    engine.mouseDown(brick.x, brick.y)
    #expect(engine.draggingIndices.isEmpty)
    engine.mouseMove(brick.x, brick.y + engine.dragResolveThreshold + 1)
    #expect(engine.draggingIndices == [brickIndex])

    // Drag it over to rest directly on the floor (top edge at y=36), landing at (0, 18);
    // account for the grab offset recorded at the resolve position above (not the original press
    // position), so this doesn't depend on the exact threshold arithmetic.
    let offsetX = engine.entities[brickIndex].grabOffsetX
    let offsetY = engine.entities[brickIndex].grabOffsetY
    engine.mouseMove(0 - offsetX, 18 - offsetY)
    #expect(engine.canRelease())
    engine.mouseUp(0 - offsetX, 18 - offsetY)
    #expect(engine.draggingIndices.isEmpty)
    #expect(!engine.entities[brickIndex].grabbed)
    #expect(engine.entities[brickIndex].x == 0)
    #expect(engine.entities[brickIndex].y == 18)
  }
}
