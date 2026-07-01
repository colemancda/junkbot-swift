import Foundation
import XCTest

@testable import JunkbotCore

final class LevelTests: XCTestCase {

  /// Repo root, resolved from this file's own path (Tests/JunkbotCoreTests/LevelTests.swift),
  /// so tests can load `levels/test-cases/*.txt` without a resource bundle.
  static var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  func loadTestCase(_ name: String) throws -> String {
    let url = Self.repoRoot.appendingPathComponent("levels/test-cases/\(name).txt")
    return try String(contentsOf: url, encoding: .utf8)
  }

  enum Expectation {
    case win, lose, draw
  }

  /// Runs a level to completion (win/lose) or up to `maxSteps`, mirroring runTests()'
  /// per-test loop in src/game.js (checkTestEnd / winOrLose each step), just without a browser.
  func runLevel(_ name: String, expect: Expectation, maxSteps: Int = 1000) throws {
    let engine = GameEngine()
    engine.loadLevel(fromText: try loadTestCase(name))

    var won = false
    var lost = false
    for _ in 0..<maxSteps {
      engine.tick()
      let state = engine.winOrLose()
      if state == 1 { won = true; break }
      if state == 2 { lost = true; break }
    }

    switch expect {
    case .win:
      XCTAssertTrue(won, "Expected \"\(name)\" to win within \(maxSteps) steps, but \(lost ? "lost instead" : "neither won nor lost")")
    case .lose:
      XCTAssertTrue(lost, "Expected \"\(name)\" to lose within \(maxSteps) steps, but \(won ? "won instead" : "neither won nor lost")")
    case .draw:
      XCTAssertTrue(!won && !lost, "Expected \"\(name)\" to draw (neither win nor lose), but \(won ? "won instead" : "lost instead")")
    }
  }

  func testTippyToast() throws {
    try runLevel("Tippy Toast", expect: .win)
  }
}
