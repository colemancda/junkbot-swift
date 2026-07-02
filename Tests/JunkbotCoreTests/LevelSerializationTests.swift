import Foundation
import Testing

@testable import JunkbotCore

@Suite("Level serialization round-trip")
struct LevelSerializationTests {

  /// Parsing a level's text, serializing it back out, and re-parsing that should produce an
  /// equal `Level` (structured comparison, not byte-for-byte text — `Level.text` doesn't
  /// preserve the exact original formatting, e.g. "none" and "on" both parse to `PartState.on`
  /// and always serialize back out as "on").
  @Test("parse -> serialize -> parse round-trips", arguments: LevelTests.allLevels.map(\.name))
  func roundTrip(_ name: String) throws {
    let originalText = try LevelTests.loadTestCase(name)
    let parsed = Level(text: originalText)
    let reparsed = Level(text: parsed.text)
    #expect(reparsed == parsed, "\"\(name)\" did not round-trip through Level.text")
  }
}
