// Pure stdlib (no Foundation) - gated out of the embedded-WASM build not because it needs
// Foundation (it doesn't) but because it transitively depends on `Level.init(text:)`/
// `loadLevel(_:)`, which use full-stdlib String operations (`.lowercased()` etc.) that pull in
// Unicode normalization tables not linkable under Embedded Swift - see those files' own notes.
// JUNKBOT_HAS_UNICODE_TABLES: set by embedded targets that CAN link the stdlib's
// Unicode data tables (ports/NDS links libswiftUnicodeDataTables.a for armv4t),
// re-enabling this file where plain embedded-WASM must exclude it.
#if !hasFeature(Embedded) || JUNKBOT_HAS_UNICODE_TABLES

extension GameEngine {

  /// Parses level text and loads it into this engine's live `entities`/`levelBounds`. A thin
  /// convenience wrapper around `Level.init(text:)` (`LevelParse.swift`) followed by
  /// `loadLevel(_:)` (`LevelEntityBridge.swift`), kept so callers (currently just
  /// `JunkbotCoreTests`) can go straight from level text to a running simulation. Not reachable
  /// from the WASM/embedded build (gated behind `hasFeature(Embedded)`).
  public func loadLevel(fromText text: String) {
    loadLevel(Level(text: text))
  }
}
#endif
