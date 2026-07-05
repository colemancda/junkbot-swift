/// Which campaign a level belongs to. Top-level (not nested in `LevelCatalog`, which is
/// Foundation-only) so it's available to every target, including Embedded ones.
public enum Game: Equatable, Sendable {
  case junkbot
  case junkbotUndercover
}

/// One level, pre-parsed at build time (`tools/LevelDump` runs the real text parser/entity
/// bridge natively and freezes the result) rather than parsed from `.txt` on-device -
/// `Sources/JunkbotCore/Generated/LevelData.swift`'s `embeddedLevels`/`titleScreenLevel`. Every
/// stored property here is Embedded-Swift-safe (`StaticString`, no `String`/`Character`
/// operations), so this type and the generated data using it compile identically for every
/// target, embedded ones included - see that generated file's header comment for why plain
/// `Level`/`LevelPart` text parsing (`LevelParse.swift`) can't be used directly on those targets.
public struct EmbeddedLevel: Sendable {
  public let title: StaticString
  public let hint: StaticString
  /// `Int32.max` = no par declared.
  public let par: Int32
  /// `nil` = the level declared no explicit playfield size (no boundary at all).
  public let bounds: LevelBounds?
  /// `-1` = no backdrop.
  public let backdropSpriteID: Int32
  public let backgroundDecals: [DecalInstance]
  public let decals: [DecalInstance]
  public let game: Game
  public let makeEntities: @Sendable () -> [Entity]

  public init(
    title: StaticString, hint: StaticString, par: Int32, bounds: LevelBounds?,
    backdropSpriteID: Int32, backgroundDecals: [DecalInstance], decals: [DecalInstance],
    game: Game, makeEntities: @escaping @Sendable () -> [Entity]
  ) {
    self.title = title
    self.hint = hint
    self.par = par
    self.bounds = bounds
    self.backdropSpriteID = backdropSpriteID
    self.backgroundDecals = backgroundDecals
    self.decals = decals
    self.game = game
    self.makeEntities = makeEntities
  }
}

// Only for native (non-Embedded) ports: `levelTitle`/`levelHint` are `String`-typed on
// `GameEngine`, and converting a `StaticString` to `String` (`.description`) is real String
// machinery this project avoids linking into embedded targets elsewhere for the same reason
// (see `Sources/JunkbotCore/Level.swift`'s note). Embedded targets (ports/NDS, the WASM build)
// don't need this convenience - they read `EmbeddedLevel.title`/`.hint` directly as
// `StaticString` for display and only need `loadLevelState`/`setBackground` from this level's
// data, not the engine's own `levelTitle`/`levelHint`/`levelPar` properties.
#if !hasFeature(Embedded)
extension GameEngine {
  /// Loads a pre-parsed `EmbeddedLevel`: entities/bounds via `loadLevelState`, plus the metadata
  /// (`levelTitle`/`levelHint`/`levelPar`) and background layers `loadLevel(_:Level)` would
  /// otherwise set, since `loadLevelState` alone only covers simulation state.
  public func loadLevel(_ level: EmbeddedLevel) {
    loadLevelState(entities: level.makeEntities(), levelBounds: level.bounds, nextID: 0)
    levelTitle = level.title.description
    levelHint = level.hint.description
    levelPar = level.par == Int32.max ? Int.max : Int(level.par)
    setBackground(
      backdropSpriteID: level.backdropSpriteID, backgroundDecals: level.backgroundDecals,
      decals: level.decals)
  }
}
#endif
