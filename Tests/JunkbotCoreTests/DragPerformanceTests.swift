import Testing

@testable import JunkbotCore

/// Characterizes `canRelease()`'s per-call cost while a drag is active, since it's recomputed
/// every single frame during rendering (`RenderList.swift`'s `buildRenderFrame`, via
/// `frame.placeable = editing || canRelease()`) for as long as the player holds a brick - unlike
/// most engine queries, which run once per input event. On fast host CPUs (this repo's Darwin/Web
/// ports, or even the 3DS/NDS's ARM11/ARM946E-S) this cost is invisible; on the N64's ~93MHz
/// VR4300 doing it 60 times/second made dragging "extremely slow" (see
/// ports/N64/source/main.swift's git history).
///
/// This originally caught a *cubic* blowup (200 entities took 534x longer than 20, not the ~10x
/// linear scaling it should have): `allConnectedToFixed()`'s `Array.contains` membership check
/// inside a full-entity scan, and `canRelease()`'s own `Array.contains` on that function's
/// returned `[Int]`. Both are now `Set`-backed (O(1) membership), which dropped 200 entities from
/// 210.8ms/call to ~2.3ms/call (93x) and the realistic 60-entity case from 7ms to ~0.24ms/call
/// (30x) - comfortably inside a 16.67ms frame budget. What's left is a legitimate O(n^2): each
/// visited node still scans every entity for vertical adjacency, since `entitiesByTopY`/
/// `entitiesByBottomY` (acceleration structures that exist for exactly this query) aren't
/// consulted here - a further optimization left for later, since it'd need care to preserve the
/// x-overlap check those dictionaries don't capture on their own.
///
/// These are characterization tests, not strict pass/fail gates (wall-clock timing is inherently
/// machine-dependent, and CI runners are noisier than a dedicated benchmark rig) - they print the
/// measured per-call cost at two entity counts so a before/after refactor comparison is visible,
/// and only fail on a blowup clearly worse than the current O(n^2) (purely quadratic scaling for
/// 10x the entities would be ~100x; this allows up to 150x before flagging red, well short of the
/// ~530x the pre-fix cubic behavior produced).
@Suite("canRelease() drag performance")
struct DragPerformanceTests {

  /// Builds a level with `count` independent bricks resting directly on a fixed floor (each its
  /// own separate single-stud brick, spaced apart so none touch each other) - `entities.count` is
  /// exactly `count + 1`. Starts a drag on the first non-floor brick and returns the engine ready
  /// for repeated `canRelease()` calls.
  static func makeEngine(brickCount count: Int) -> GameEngine {
    let engine = GameEngine()
    let floorWidthStuds: Int32 = Int32(count) * 3 + 10
    engine.beginLoadLevel(0, 0, floorWidthStuds * CELL_W, 300)
    engine.addBrick(0, 36, floorWidthStuds, 0, true)  // fixed floor, top edge at y=36
    for i in 0..<count {
      engine.addBrick(Int32(i) * 3 * CELL_W, 18, 1, 0, false)  // independent, resting on the floor
    }
    engine.finishLoadLevel()

    // Grab the first non-floor brick (index 1: index 0 is the floor).
    let brick = engine.entities[1]
    engine.mouseDown(brick.x + 1, brick.y + 1)
    #expect(engine.isDragging, "setup should have started a drag on the first brick")
    return engine
  }

  /// Average wall-clock time (seconds) of `iterations` back-to-back `canRelease()` calls.
  static func averageCanReleaseTime(_ engine: GameEngine, iterations: Int) -> Double {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
      for _ in 0..<iterations {
        _ = engine.canRelease()
      }
    }
    return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
  }

  @Test("canRelease() cost scales quadratically (not cubically+) with entity count")
  func canReleaseScalesReasonably() {
    let smallCount = 20
    let largeCount = 200  // 10x the entities

    let smallEngine = Self.makeEngine(brickCount: smallCount)
    let smallTime = Self.averageCanReleaseTime(smallEngine, iterations: 200) / 200

    let largeEngine = Self.makeEngine(brickCount: largeCount)
    let largeTime = Self.averageCanReleaseTime(largeEngine, iterations: 200) / 200

    print("canRelease(): \(smallCount) entities -> \(smallTime * 1000)ms/call, "
      + "\(largeCount) entities -> \(largeTime * 1000)ms/call "
      + "(\(largeTime / max(smallTime, 1e-9))x for 10x the entities)")

    // Purely quadratic scaling would be ~100x for 10x the entities; allow up to 150x before
    // treating this as a regression (a noisy CI runner shouldn't false-positive here), while still
    // catching a return to the pre-fix cubic-ish behavior (which measured ~530x).
    #expect(
      largeTime < smallTime * 150 + 0.001,
      "canRelease() took \(largeTime * 1000)ms/call at \(largeCount) entities vs \(smallTime * 1000)ms/call at \(smallCount) entities - looks worse than quadratic"
    )
  }

  @Test("canRelease() absolute cost at a realistic busy-level entity count")
  func canReleaseAbsoluteCost() {
    // Roughly the entity count of a busy campaign level (see e.g. Sources/JunkbotCore's own
    // level data) - not a worst case, just a realistic one.
    let engine = Self.makeEngine(brickCount: 60)
    let perCall = Self.averageCanReleaseTime(engine, iterations: 500) / 500
    print("canRelease(): 60 entities -> \(perCall * 1000)ms/call")
    // Measured ~0.24ms/call after the Set-backed fix (was ~7ms/call before) on this host; even
    // with a generous 10x margin for a slower/noisier machine, that's still comfortably inside a
    // 16.67ms frame budget. This won't catch a return to N64-scale slowness on its own (this repo
    // has no N64-timing-accurate benchmark), but it does catch a gross regression on any host.
    #expect(perCall < 0.010, "canRelease() took \(perCall * 1000)ms/call for a realistic 60-entity level - unexpectedly slow")
  }
}
