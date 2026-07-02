import Testing

@testable import JunkbotCore

@Suite("Play-mode drag input")
struct InputTests {

  /// A fixed floor brick spanning most of the level, for things to rest on.
  static func makeFloor(_ engine: GameEngine, y: Int32) {
    engine.addBrick(0, y, 20, 0, true)
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

  @Test("Grabbing a brick with unconnected bricks both above and below is ambiguous until the drag resolves")
  func ambiguousDirectionPendsUntilResolved() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    engine.addBrick(0, 0, 1, 0, false)  // C
    engine.addBrick(0, -18, 1, 0, false)  // D, directly above C; nothing below C
    engine.finishLoadLevel()

    let cIndex = engine.entities.firstIndex { $0.x == 0 && $0.y == 0 }!
    let cEntity = engine.entities[cIndex]

    engine.mouseDown(cEntity.x + 1, cEntity.y + 1)
    #expect(engine.draggingIndices.isEmpty, "should not commit to a direction immediately")
    #expect(engine.pendingGrabDownward != nil)
    #expect(engine.pendingGrabUpward != nil)

    // Drag gesture resolves downward (grabbing just C, since nothing rests below it).
    engine.mouseMove(cEntity.x + 1, cEntity.y + 1 + engine.dragResolveThreshold + 1)
    #expect(engine.draggingIndices == [cIndex])
    #expect(engine.pendingGrabDownward == nil && engine.pendingGrabUpward == nil)
  }

  @Test("canRelease rejects a position adjacent to a fire hazard even if otherwise well-supported")
  func releaseRejectedNearFire() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    Self.makeFloor(engine, y: 18)  // fixed floor, top edge at y=18
    engine.addBrick(0, 0, 1, 0, false)  // draggable brick resting on the floor
    engine.addFire(15, 0, true, -1)  // fire directly beside the brick, same row

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

    engine.mouseDown(brick.x + 1, brick.y + 1)
    #expect(engine.draggingIndices == [brickIndex], "isolated single brick should be immediately draggable in whichever direction resolves")

    // Drag it over to rest directly on the floor at x=0.
    engine.mouseMove(1, 19)
    #expect(engine.canRelease())
    engine.mouseUp(1, 19)
    #expect(engine.draggingIndices.isEmpty)
    #expect(!engine.entities[brickIndex].grabbed)
    #expect(engine.entities[brickIndex].y == 18)
  }
}
