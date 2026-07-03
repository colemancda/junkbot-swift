import Testing

@testable import JunkbotCore

/// Covers `GameEngine.simulateSwitches()`'s rising-edge latch (`Entity.steppedOn`), added to
/// match the original Lingo's `hazard slick switch parent.ls` - which checks its own occupancy
/// every frame, independent of the minifig's walk cadence, and toggles exactly once per
/// continuous occupancy rather than once per tick/walk-step it happens to still be standing
/// there. See the doc comment on `simulateSwitches()` (Simulation.swift) for the full rationale.
@Suite("Switch rising-edge trigger")
struct SwitchTests {

  @Test("A switch toggles exactly once while Junkbot remains on it, even when he's permanently blocked from walking away")
  func togglesOnceWhileStuck() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 600, 600)

    let switchY: Int32 = 200
    let junkbotY = switchY - 4 * CELL_H  // Junkbot's feet (y + height) land exactly on the switch.
    engine.addSwitch(0, switchY, false, -1)
    engine.addJunkbot(0, junkbotY, 1, false)
    // Fixed walls flanking Junkbot at his own height, so `walk()` always finds itself blocked in
    // both directions and never actually leaves the switch's tile (matches the "Switch Off At
    // Edge Case" scenario: stuck turning in place while still standing on the switch).
    engine.addBrick(-2 * CELL_W, junkbotY, 2, 0, true)
    engine.addBrick(2 * CELL_W, junkbotY, 2, 0, true)
    engine.finishLoadLevel()

    var switchClicks = 0
    engine.onPlaySound = { id in if id == SoundID.switchClick.rawValue { switchClicks += 1 } }

    for _ in 0..<40 { engine.tick() }

    let switchIndex = engine.entities.firstIndex { $0.type == .switch }!
    #expect(engine.entities[switchIndex].on, "the switch should have toggled on")
    #expect(
      switchClicks == 1,
      "expected exactly one toggle despite Junkbot remaining on the switch for many ticks, got \(switchClicks)"
    )
  }

  @Test("Leaving the switch and returning re-arms its trigger")
  func retriggersAfterLeaving() {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 600, 600)

    let switchY: Int32 = 200
    let junkbotY = switchY - 4 * CELL_H
    engine.addSwitch(0, switchY, false, -1)
    engine.addJunkbot(0, junkbotY, 1, false)
    engine.finishLoadLevel()

    let switchIndex = engine.entities.firstIndex { $0.type == .switch }!

    // Tick 1: Junkbot starts already aligned on the switch -> rising edge -> toggles on.
    engine.tick()
    #expect(engine.entities[switchIndex].on)
    #expect(engine.entities[switchIndex].steppedOn)

    // Move Junkbot off the switch directly (bypassing walk cadence, for a deterministic repro)
    // and tick once: the occupancy check should fail and clear the latch, with no re-toggle.
    let junkbotIndex = engine.entities.firstIndex { $0.type == .junkbot }!
    engine.entities[junkbotIndex].x += 4 * CELL_W
    engine.tick()
    #expect(!engine.entities[switchIndex].steppedOn, "latch should clear once Junkbot is no longer aligned")
    #expect(engine.entities[switchIndex].on, "moving away shouldn't itself flip the switch back off")

    // Move back onto the switch: this is a fresh occupancy, so it should legitimately retrigger.
    engine.entities[junkbotIndex].x -= 4 * CELL_W
    engine.tick()
    #expect(!engine.entities[switchIndex].on, "returning to the switch should toggle it again (off)")
    #expect(engine.entities[switchIndex].steppedOn)
  }
}
