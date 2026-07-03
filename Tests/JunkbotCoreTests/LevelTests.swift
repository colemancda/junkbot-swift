import Foundation
import Testing

@testable import JunkbotCore

enum Expectation: Sendable {
  case win, lose, draw
}

struct LevelCase: Sendable, CustomTestStringConvertible {
  let name: String
  let expect: Expectation
  /// See the comment on `LevelTests.levelOutcome` for why some levels are marked known-failing.
  let knownFailing: Bool

  init(_ name: String, _ expect: Expectation, knownFailing: Bool = false) {
    self.name = name
    self.expect = expect
    self.knownFailing = knownFailing
  }

  var testDescription: String { name }
}

@Suite("Level simulation")
struct LevelTests {

  /// Repo root, resolved from this file's own path (Tests/JunkbotCoreTests/LevelTests.swift),
  /// so tests can load `levels/test-cases/*.txt` without a resource bundle.
  static var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  static func loadTestCase(_ name: String) throws -> String {
    let url = repoRoot.appendingPathComponent("levels/test-cases/\(name).txt")
    return try String(contentsOf: url, encoding: .utf8)
  }

  static let allLevels: [LevelCase] = [
    LevelCase("Tippy Toast", .win),
    LevelCase("Tight Squeeze Stairs", .win),
    LevelCase("Shallow Steps", .win),
    LevelCase("Don't Skate The Crate", .win),
    LevelCase("Twixt Crates", .win),
    LevelCase("Armor Farmer", .win),
    LevelCase("Armor Harmer", .lose),
    LevelCase("Out of the Frying Pan And Into The Fire (Murder)", .draw),
    LevelCase("Out of the Frying Pan And Into The Fire (Vengeance)", .lose),
    LevelCase("Once You Win, You Won", .win),
    LevelCase("You'll Be Shocked!", .lose),
    LevelCase("All-Off Offal", .win),
    LevelCase("Switch Off At Edge Case", .win),
    LevelCase("Scared Off", .lose),
    LevelCase("Scared Off II Junkbot's Jowls", .win),
    LevelCase("Jump Stair Case", .win),
    LevelCase("Jump Around (bricks in place)", .win),
    LevelCase("Jump Around (bricks out of place)", .draw),
    LevelCase("Perpetual Motion Machine (Test)", .win),
    LevelCase("Jump Up Just To Edge", .win),
    LevelCase("Collide With Bins In Midair", .win),
    LevelCase("Don't Get Stuck On Jump", .win),
    LevelCase("Bounce Against Wall", .win),
    LevelCase("Turning Shouldn't Jump", .win),
    LevelCase("Portable Boost (Test)", .win),
    LevelCase("Blocked Teleport", .lose),
    LevelCase("Lasers Not Blocked By Water", .lose),
    LevelCase("Lasers Blocked By Gearbots", .win),
    LevelCase("Don't Step Up Onto Gearbot", .win),
    LevelCase("Don't Walk Over Gearbot", .win),
    LevelCase("Don't Step Down Onto Gearbot", .win),
    LevelCase("Step Down Onto Falling Crate", .win),
    LevelCase("Don't Walk Over Bins", .win),
    LevelCase("Don't Step Down Onto Bins", .win),
    LevelCase("Death From Below", .lose),
    LevelCase("Flying Death", .lose),
    LevelCase("Turn Away from Climbbot I", .win),
    LevelCase("Turn Away from Climbbot II", .win),
    LevelCase("Crate Fall Onto Offset Blocks", .win),
    LevelCase("Gearbot Fall Onto Offset Blocks", .lose),
    LevelCase("Climbbot Fall Onto Offset Blocks", .lose),
    LevelCase("Hunter-Killer Climbbot (Fall Onto Offset Blocks)", .lose),
    LevelCase("Ally", .win),
  ]

  /// Runs a level for up to `maxSteps`, mirroring runTests()' per-test loop in src/game.js.
  /// `GameEngine.winLoseState` now latches once it reaches a terminal result (see the comment on
  /// `simulate()` in Simulation.swift) - matching the original Lingo's one-shot
  /// `addStatus(#damage/#goals, ...)` event model - so it can no longer flip from win back to
  /// lose (or vice versa) on a later tick; checking it after the loop (rather than OR-ing
  /// win/lose across every step, as this used to) is now sufficient.
  func runLevel(_ testCase: LevelCase, maxSteps: Int = 1000) throws {
    let engine = GameEngine()
    engine.loadLevel(fromText: try Self.loadTestCase(testCase.name))

    for _ in 0..<maxSteps {
      engine.tick()
      if engine.winLoseState != 0 { break }
    }

    switch testCase.expect {
    case .win:
      #expect(
        engine.winLoseState == 1,
        "Expected \"\(testCase.name)\" to win within \(maxSteps) steps, but \(engine.winLoseState == 2 ? "lost instead" : "neither won nor lost")"
      )
    case .lose:
      #expect(
        engine.winLoseState == 2,
        "Expected \"\(testCase.name)\" to lose within \(maxSteps) steps, but \(engine.winLoseState == 1 ? "won instead" : "neither won nor lost")"
      )
    case .draw:
      #expect(
        engine.winLoseState == 0,
        "Expected \"\(testCase.name)\" to draw (neither win nor lose), but \(engine.winLoseState == 1 ? "won instead" : "lost instead")"
      )
    }
  }

  @Test("Level outcome matches expectation", arguments: allLevels)
  func levelOutcome(_ testCase: LevelCase) throws {
    if testCase.knownFailing {
      withKnownIssue("Known bug: junkbot wins then later dies in \"\(testCase.name)\" (see comment on LevelTests.allLevels)") {
        try runLevel(testCase)
      }
    } else {
      try runLevel(testCase)
    }
  }
}
