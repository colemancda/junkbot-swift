import Testing

@testable import JunkbotCore

@Suite("Play-mode rewind")
struct RewindTests {

  @Test("stepRewind() restores each earlier tick's state in order")
  func stepRewindRestoresEachEarlierTick() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 600, 600)
    engine.addBrick(0, 500, 20, 0, true)  // fixed floor, far below
    engine.addBrick(0, 0, 1, 0, false)  // unsupported brick, falls CELL_H per tick
    engine.finishLoadLevel()

    let brickIndex = engine.entities.firstIndex { $0.type == .brick && !$0.fixed }!

    let tickCount = 5
    var yAfterTick: [Int32] = [engine.entities[brickIndex].y]  // index 0 = initial state, frame 0
    for _ in 0..<tickCount {
      engine.tick()
      yAfterTick.append(engine.entities[brickIndex].y)
    }
    #expect(engine.frameCounter == Int32(tickCount))
    // Sanity check the brick is actually still falling throughout, i.e. state genuinely differs
    // tick to tick (otherwise this test wouldn't be able to tell a correct restore from a
    // no-op/garbage one).
    #expect(Set(yAfterTick).count == tickCount + 1)

    engine.beginRewind()
    for step in 1...tickCount {
      let didStep = engine.stepRewind()
      #expect(didStep)
      let expectedFrame = Int32(tickCount - step)
      #expect(engine.frameCounter == expectedFrame)
      #expect(engine.entities[brickIndex].y == yAfterTick[tickCount - step])
    }
    engine.endRewind()
  }

  @Test("stepRewind() returns false once frameCounter reaches 0")
  func stepRewindStopsAtFrameZero() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 300, 300)
    engine.addBrick(0, 0, 1, 0, false)
    engine.finishLoadLevel()

    #expect(engine.frameCounter == 0)
    engine.beginRewind()
    #expect(!engine.stepRewind())
    #expect(engine.frameCounter == 0)
    engine.endRewind()
  }

  @Test("stepRewind() fails gracefully once the ring buffer has wrapped past capacity")
  func stepRewindFailsClosedOnWraparound() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 600, 600)
    engine.addBrick(0, 36, 20, 0, true)  // fixed floor, brick settles quickly and then holds still
    engine.addBrick(0, 0, 1, 0, false)
    engine.finishLoadLevel()

    let bufferCapacity = 600
    let overrun = 10
    for _ in 0..<(bufferCapacity + overrun) {
      engine.tick()
    }
    #expect(engine.frameCounter == Int32(bufferCapacity + overrun))

    engine.beginRewind()
    for _ in 0..<bufferCapacity {
      #expect(engine.stepRewind())
    }
    #expect(engine.frameCounter == Int32(overrun))

    // One more step would need frame (overrun - 1), which has already been overwritten by the
    // wraparound — must fail closed rather than restore the wrong frame's state.
    #expect(!engine.stepRewind())
    #expect(engine.frameCounter == Int32(overrun))
    engine.endRewind()
  }
}
