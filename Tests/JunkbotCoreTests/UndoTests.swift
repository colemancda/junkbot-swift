import Testing

@testable import JunkbotCore

@Suite("Play-mode undo")
struct UndoTests {

  @Test("undo() reverts the last completed move")
  func undoRevertsLastMove() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 600, 600)
    engine.addBrick(0, 36, 20, 0, true)  // fixed floor
    engine.addBrick(60, 0, 1, 0, false)  // draggable brick, starts unsupported off to the side
    engine.finishLoadLevel()

    let brickIndex = engine.entities.firstIndex { $0.type == .brick && !$0.fixed }!
    let startX = engine.entities[brickIndex].x
    let startY = engine.entities[brickIndex].y
    #expect(engine.moves == 0)
    #expect(!engine.canUndo)

    // Press, then move enough to cross the direction-resolve threshold (starting the drag), then
    // move again to the actual drop position, then release.
    engine.mouseDown(60, 0)
    engine.mouseMove(60, 30)
    engine.mouseMove(60, 48)
    engine.mouseUp(60, 48)

    #expect(engine.moves == 1)
    #expect(engine.entities[brickIndex].x == 60)
    #expect(engine.entities[brickIndex].y == 18)
    #expect(!engine.entities[brickIndex].grabbed)
    #expect(engine.canUndo)

    let didUndo = engine.undo()
    #expect(didUndo)
    #expect(engine.moves == 0)
    #expect(engine.entities[brickIndex].x == startX)
    #expect(engine.entities[brickIndex].y == startY)
    #expect(!engine.entities[brickIndex].grabbed)
    #expect(!engine.canUndo)
  }

  @Test("undo() returns false when there is nothing to undo")
  func undoNoOpsWhenStackEmpty() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    engine.addBrick(0, 0, 1, 0, false)
    engine.finishLoadLevel()

    #expect(!engine.canUndo)
    #expect(!engine.undo())
  }

  @Test("undo() is refused while a drag is in progress")
  func undoRefusedMidDrag() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    engine.addBrick(0, 36, 20, 0, true)  // fixed floor, top edge at y=36
    engine.addBrick(0, 18, 1, 0, false)  // resting directly on the floor: only "upward" is
    // grabbable (downward would drag the fixed floor), so mouseDown alone starts the drag
    // immediately, no direction-resolution mouseMove needed.
    engine.finishLoadLevel()

    engine.mouseDown(0, 18)
    #expect(engine.isDragging)
    #expect(engine.canUndo, "a snapshot should have been pushed at drag-start")
    #expect(!engine.undo(), "undo() should refuse to act while mid-drag")
    #expect(engine.isDragging, "the in-progress drag should be untouched by the refused undo")
  }
}
