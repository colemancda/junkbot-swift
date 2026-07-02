#if canImport(Foundation)
import Foundation

extension GameEngine {

  /// Parses level text and loads it into this engine's live `entities`/`levelBounds`. A thin
  /// convenience wrapper around `Level.init(text:)` (`LevelParse.swift`) followed by
  /// `loadLevel(_:)` (`LevelEntityBridge.swift`), kept so callers (currently just
  /// `JunkbotCoreTests`) can go straight from level text to a running simulation. Not reachable
  /// from the WASM/embedded build (gated behind `canImport(Foundation)`).
  public func loadLevel(fromText text: String) {
    loadLevel(Level(text: text))
  }
}
#endif
