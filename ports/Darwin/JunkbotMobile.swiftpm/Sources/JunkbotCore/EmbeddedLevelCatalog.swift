// Only for native (non-Embedded) ports: mirrors `LevelCatalog`'s pagination/lookup API
// (`pagesByGame`/`location(ofLevelTitled:game:)`/`nextLevel(after:game:)`) closely enough that a
// port can swap one for the other with minimal call-site changes, but built from the
// build-time-generated `embeddedLevels` (`Generated/LevelData.swift`) instead of scanning
// `levels/*.txt` at runtime - no `repoRoot`, no file I/O, no text parsing. `LevelCatalog` itself
// stays around unused-by-ports (see its own doc comment) since it's what `tools/LevelDump` uses
// to produce that generated data in the first place, and its round-trip is exercised by tests.
#if !hasFeature(Embedded)

/// One level within `EmbeddedLevelCatalog`'s pagination - `title`/`par` as plain `String`/`Int?`
/// (matching `LevelCatalogEntry`'s field types) since, unlike the underlying `EmbeddedLevel`,
/// this type only exists in non-Embedded builds where `String` is unrestricted.
public struct EmbeddedLevelEntry: Sendable {
  public let title: String
  /// `nil` = no par declared (mirrors `LevelCatalogEntry.par`'s convention, not
  /// `EmbeddedLevel.par`'s `Int32.max` sentinel).
  public let par: Int?
  public let level: EmbeddedLevel

  init(_ level: EmbeddedLevel) {
    self.title = level.title.description
    self.par = level.par == Int32.max ? nil : Int(level.par)
    self.level = level
  }
}

public struct EmbeddedLevelCatalog: Sendable {
  /// 15-level pages, in listing order (mirrors `LevelCatalog.pagesByGame`'s pagination exactly).
  public let pagesByGame: [Game: [[EmbeddedLevelEntry]]]

  private static let pageSize = 15

  public init() {
    var flatByGame: [Game: [EmbeddedLevelEntry]] = [:]
    for level in embeddedLevels {
      flatByGame[level.game, default: []].append(EmbeddedLevelEntry(level))
    }
    pagesByGame = flatByGame.mapValues { entries in
      stride(from: 0, to: entries.count, by: Self.pageSize).map {
        Array(entries[$0..<min($0 + Self.pageSize, entries.count)])
      }
    }
  }

  /// The page/position of the level titled `title` within `game`, or `nil` if not found.
  public func location(ofLevelTitled title: String, game: Game) -> (page: Int, indexInPage: Int)? {
    guard let pages = pagesByGame[game] else { return nil }
    for (pageIndex, page) in pages.enumerated() {
      if let entryIndex = page.firstIndex(where: { $0.title == title }) {
        return (pageIndex, entryIndex)
      }
    }
    return nil
  }

  /// The level immediately following `title` within `game`'s full (unpaginated) sequence, or
  /// `nil` if `title` is the last level.
  public func nextLevel(after title: String, game: Game) -> EmbeddedLevelEntry? {
    let flat = (pagesByGame[game] ?? []).flatMap { $0 }
    guard let index = flat.firstIndex(where: { $0.title == title }) else { return nil }
    let nextIndex = flat.index(after: index)
    return nextIndex < flat.endIndex ? flat[nextIndex] : nil
  }
}

#endif
