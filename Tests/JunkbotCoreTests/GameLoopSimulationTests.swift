import Testing

@testable import JunkbotCore

/// Simulates the real embedded-port main loop (`ports/N64`/`ports/NDS`'s `loadLevel` + per-frame
/// `tick()`/`buildRenderFrame(visibleBounds:)`/viewport scroll) against actual campaign level data,
/// to characterize why level 1 ("New Employee Training", 120 reserved entities) still feels slower
/// than level 2 ("Art in the Lobby", 40 reserved entities) even after `buildRenderFrame` gained
/// viewport culling. Unlike `DragPerformanceTests.swift`/`RenderListTests.swift`'s synthetic
/// bricks-on-a-floor levels, this drives the *real* level data so both the render-cull pass (an
/// O(n) scan over every entity, culled or not) and `tick()` (which processes every entity every
/// call regardless of visibility - simulation isn't scoped to the viewport at all) are measured
/// together, the same combination the console actually pays for each frame.
@Suite("Real-level game loop simulation")
struct GameLoopSimulationTests {
  /// Mirrors `ports/N64/source/main.swift`'s `screenWidth`/`screenHeight`/margin exactly, so the
  /// culled entity count matches what the N64/NDS ports actually see.
  static let screenWidth: Int32 = 320
  static let screenHeight: Int32 = 240
  static let margin: Int32 = 64

  /// Loads a campaign level and centers the viewport on Junkbot's start position, exactly like
  /// `loadLevel(_:)` + `clampScroll()` in `ports/N64/source/main.swift`.
  func loadLevel(_ index: Int) -> (engine: GameEngine, scrollX: Int32, scrollY: Int32) {
    let engine = GameEngine()
    let level = junkbotCampaignLevels[index]
    engine.loadLevelState(entities: level.makeEntities(), levelBounds: level.bounds, nextID: 0)

    var scrollX: Int32 = 0
    var scrollY: Int32 = 0
    for entity in engine.entities where entity.type == .junkbot {
      scrollX = entity.x + entity.width / 2 - Self.screenWidth / 2
      scrollY = entity.y + entity.height / 2 - Self.screenHeight / 2
      break
    }
    if let bounds = level.bounds {
      if bounds.width <= Self.screenWidth {
        scrollX = bounds.x - (Self.screenWidth - bounds.width) / 2
      } else {
        scrollX = min(max(scrollX, bounds.x), bounds.x + bounds.width - Self.screenWidth)
      }
      if bounds.height <= Self.screenHeight {
        scrollY = bounds.y - (Self.screenHeight - bounds.height) / 2
      } else {
        scrollY = min(max(scrollY, bounds.y), bounds.y + bounds.height - Self.screenHeight)
      }
    }
    return (engine, scrollX, scrollY)
  }

  /// Runs `frameCount` frames of the real loop shape: `tick()` (18Hz in the actual ports, called
  /// every frame here to bound worst case) then a viewport-culled `buildRenderFrame`, with the
  /// scroll position sweeping across the level bounds to exercise different visible subsets like
  /// actual scrolled gameplay, not a single fixed camera position.
  func simulateFrames(_ index: Int, frameCount: Int) -> (tickSeconds: Double, renderSeconds: Double) {
    let (engine, startX, startY) = loadLevel(index)
    let bounds = engine.levelBounds
    var frame = RenderFrame()
    let clock = ContinuousClock()

    var tickTotal = Duration.zero
    var renderTotal = Duration.zero
    for i in 0..<frameCount {
      let t = Double(i) / Double(max(frameCount - 1, 1))
      var scrollX = startX
      var scrollY = startY
      if let b = bounds, b.width > Self.screenWidth {
        scrollX = b.x + Int32(Double(b.width - Self.screenWidth) * t)
      }
      if let b = bounds, b.height > Self.screenHeight {
        scrollY = b.y + Int32(Double(b.height - Self.screenHeight) * t)
      }

      tickTotal += clock.measure { engine.tick() }

      let visible = LevelBounds(
        x: scrollX - Self.margin, y: scrollY - Self.margin,
        width: Self.screenWidth + Self.margin * 2, height: Self.screenHeight + Self.margin * 2)
      renderTotal += clock.measure {
        engine.buildRenderFrame(into: &frame, editing: false, visibleBounds: visible)
      }
    }
    return (
      Double(tickTotal.components.seconds) + Double(tickTotal.components.attoseconds) * 1e-18,
      Double(renderTotal.components.seconds) + Double(renderTotal.components.attoseconds) * 1e-18
    )
  }

  @Test("Level 1 has substantially more entities than level 2")
  func levelEntityCounts() {
    let level1 = GameEngine()
    level1.loadLevelState(
      entities: junkbotCampaignLevels[0].makeEntities(), levelBounds: junkbotCampaignLevels[0].bounds,
      nextID: 0)
    let level2 = GameEngine()
    level2.loadLevelState(
      entities: junkbotCampaignLevels[1].makeEntities(), levelBounds: junkbotCampaignLevels[1].bounds,
      nextID: 0)
    #expect(level1.entities.count > level2.entities.count)
  }

  /// Characterizes the actual per-frame cost gap: `tick()` runs over every entity regardless of
  /// the viewport, so level 1's larger entity count makes it slower even with render culling
  /// doing its job - this is the mechanism behind "level 1 is still slower than level 2".
  @Test("tick() cost scales with level 1's larger total entity count, not just render cost")
  func tickCostReflectsEntityCount() {
    let level1 = simulateFrames(0, frameCount: 60)
    let level2 = simulateFrames(1, frameCount: 60)

    let level1TickPerFrame = level1.tickSeconds / 60
    let level2TickPerFrame = level2.tickSeconds / 60

    #expect(
      level1TickPerFrame > level2TickPerFrame,
      "level 1 tick() per-frame cost (\(level1TickPerFrame)s) should exceed level 2's (\(level2TickPerFrame)s), since tick() isn't scoped to the viewport"
    )
  }

  /// Measured finding: viewport culling does NOT close the level1-vs-level2 gap much, because
  /// level 1's world bounds (525x396) are barely bigger than the 320x240 screen - at almost any
  /// scroll position within its bounds, most of its 120 entities are still inside the culled
  /// visibleBounds rect. Culling only pays off when a level's world is much larger than one
  /// screen (letting most entities fall outside the rect at any given scroll position); a small,
  /// entity-dense level like level 1 keeps close to its full entity count "visible" regardless of
  /// scroll, so its render cost tracks its tick cost (both driven by total entity count) rather
  /// than dropping to match level 2's. The remaining fix, if this gap matters in practice, is
  /// entity count itself (level 1's ~120 vs level 2's ~40, mostly redundant small floor-segment
  /// bricks - see `Sources/JunkbotCore/Generated/JunkbotLevelData.swift`), not more culling.
  @Test("render cost tracks tick cost for a small, entity-dense level like level 1")
  func renderCostTracksEntityCountForSmallLevels() {
    let level1 = simulateFrames(0, frameCount: 60)
    let level2 = simulateFrames(1, frameCount: 60)

    let tickRatio = level1.tickSeconds / max(level2.tickSeconds, 1e-9)
    let renderRatio = level1.renderSeconds / max(level2.renderSeconds, 1e-9)

    // Both ratios should be in the same ballpark (within 3x of each other) - if render cost were
    // dramatically smaller than tick cost's ratio, that would mean culling IS helping here after
    // all and this comment/finding would be stale.
    #expect(
      renderRatio > tickRatio / 3,
      "render ratio (\(renderRatio)x) is much smaller than tick ratio (\(tickRatio)x) - culling may be working better than expected here; re-check this test's assumptions"
    )
  }

  /// Absolute per-frame budget check at 60 real frames (with tick() running every frame, the
  /// worst case - real ports call it at ~18Hz, roughly a third as often): total combined cost per
  /// frame should stay well under a 16.6ms (60fps) budget on this Mac, since a much slower
  /// embedded CPU needs real headroom below that already-generous ceiling.
  @Test("level 1's combined per-frame cost stays within a sane budget")
  func level1FrameBudget() {
    let level1 = simulateFrames(0, frameCount: 60)
    let perFrame = (level1.tickSeconds + level1.renderSeconds) / 60
    #expect(perFrame < 0.005, "level 1 combined tick+render per-frame cost was \(perFrame)s")
  }

  /// Isolated `tick()`-only measurement (no render call in the loop at all), at a larger frame
  /// count for a stabler average, with the measured ratio printed so it shows up in `swift test`
  /// output for direct before/after comparison without re-deriving it from the combined numbers.
  @Test("tick()-only cost: level 1 vs level 2, isolated from rendering")
  func tickOnlyCostComparison() {
    let (level1Engine, _, _) = loadLevel(0)
    let (level2Engine, _, _) = loadLevel(1)
    let clock = ContinuousClock()
    let frameCount = 300

    let level1Duration = clock.measure {
      for _ in 0..<frameCount { level1Engine.tick() }
    }
    let level2Duration = clock.measure {
      for _ in 0..<frameCount { level2Engine.tick() }
    }

    let level1PerTick = level1Duration / frameCount
    let level2PerTick = level2Duration / frameCount
    let level1Entities = level1Engine.entities.count
    let level2Entities = level2Engine.entities.count
    let ratio =
      Double(level1Duration.components.attoseconds) / Double(max(level2Duration.components.attoseconds, 1))

    print(
      "tick(): level 1 (\(level1Entities) entities) -> \(level1PerTick)/call, "
        + "level 2 (\(level2Entities) entities) -> \(level2PerTick)/call, \(ratio)x"
    )

    #expect(level1Duration > level2Duration)
  }

  /// Normalizes tick() cost per-entity (total tick time / entity count) to check whether the
  /// gap is explained *entirely* by entity count (ratio near 1.0, meaning simulate()'s per-entity
  /// work is roughly linear) or whether level 1 pays a super-linear penalty beyond just having
  /// more entities (ratio > 1.0) - e.g. from the two full `entities.sort` calls in `simulate()`
  /// (`Sources/JunkbotCore/Simulation.swift`), which are O(n log n) rather than O(n), or from
  /// `simulateGravity`'s `connectsToFixed` calls, which walk connected-entity chains and so can
  /// cost more than a flat per-entity constant on a level with many stacked/adjacent bricks.
  @Test("tick() per-entity cost: is level 1's gap fully explained by entity count alone?")
  func tickCostPerEntity() {
    let (level1Engine, _, _) = loadLevel(0)
    let (level2Engine, _, _) = loadLevel(1)
    let clock = ContinuousClock()
    let frameCount = 300

    let level1Duration = clock.measure {
      for _ in 0..<frameCount { level1Engine.tick() }
    }
    let level2Duration = clock.measure {
      for _ in 0..<frameCount { level2Engine.tick() }
    }

    let level1PerEntityPerTick =
      Double(level1Duration.components.attoseconds) / Double(frameCount) / Double(level1Engine.entities.count)
    let level2PerEntityPerTick =
      Double(level2Duration.components.attoseconds) / Double(frameCount) / Double(level2Engine.entities.count)
    let perEntityRatio = level1PerEntityPerTick / max(level2PerEntityPerTick, 1)

    print(
      "tick() per-entity-per-call: level 1 -> \(level1PerEntityPerTick)as, "
        + "level 2 -> \(level2PerEntityPerTick)as, ratio \(perEntityRatio)x"
    )

    // A generous ceiling: some super-linear cost (sorting, connected-chain walks) is expected and
    // fine, but a per-entity ratio blowing up far past ~3x would point at an actual algorithmic
    // bug rather than just "more entities costs more", worth a follow-up investigation like the
    // canRelease() one in DragPerformanceTests.swift.
    #expect(
      perEntityRatio < 3,
      "level 1's per-entity tick cost (\(level1PerEntityPerTick)as) is more than 3x level 2's (\(level2PerEntityPerTick)as) - entity count alone may not explain the gap"
    )
  }
}
