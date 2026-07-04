#if canImport(Foundation)
import Foundation

/// Reads `_LEVEL_LISTING.txt` (and its Undercover counterpart) and groups the results into
/// 15-level pages ("buildings"/"basements"), mirroring `src/game.js`'s `getLevelLists`
/// (`levelsPerPage: 15` for both games) and `whereLevelIsInTheGame`. Unlike `LevelParse.swift`/
/// `LevelSerialize.swift`/`LevelEntityBridge.swift` (excluded from Embedded only for an
/// unrelated Unicode-table linking concern, not a real Foundation need), this file genuinely
/// needs Foundation for real directory/file I/O (`URL`, `FileManager`, `String(contentsOf:)`) -
/// there's no stdlib-only way to do that on any platform. Reachable only from native targets
/// (SDL3, tests), tree-shaken out of the embedded-WASM build since nothing in
/// `Sources/JunkbotWASM/main.swift` references it either way. Test-cases and user-created
/// (editor) levels are out of scope here - the browser build treats those as unpaginated
/// (`levelsPerPage: Infinity`) and this catalog only covers the two paginated games.
public struct LevelCatalogEntry: Equatable, Sendable {
  public let title: String
  public let url: URL
  public let par: Int?

  public init(title: String, url: URL, par: Int?) {
    self.title = title
    self.url = url
    self.par = par
  }
}

public struct LevelCatalog: Sendable {
  public enum Game: Equatable, Sendable {
    case junkbot
    case junkbotUndercover
  }

  /// 15-level pages, in listing order; the last page of a game may be shorter (Undercover's
  /// listing has 61 entries, not a multiple of 15 - see `Project X`, alone on page 5).
  public let pagesByGame: [Game: [[LevelCatalogEntry]]]

  private static let pageSize = 15

  /// Reads a level `.txt` file as UTF-8, stripping a leading byte-order-mark if present - some
  /// files under `levels/` have one, and `String(contentsOf:encoding:)` doesn't strip it
  /// automatically, which would otherwise glue a stray `\u{FEFF}` to the `[info]` line and break
  /// that file's section parsing silently (`Level(text:)` isn't throwing).
  private static func readLevelText(at url: URL) -> String? {
    guard var text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    if text.hasPrefix("\u{FEFF}") {
      text.removeFirst()
    }
    return text
  }

  /// Collapses runs of whitespace to a single space, for matching titles that differ only in
  /// incidental whitespace (a couple of level files have a typo'd double space in their `title=`
  /// line versus their `_LEVEL_LISTING.txt` entry). Plain stdlib `split` (default
  /// `omittingEmptySubsequences: true`) already drops leading/trailing spaces too - no separate
  /// Foundation `CharacterSet` trim needed.
  private static func normalizedTitle(_ title: String) -> String {
    title.split(separator: " ").joined(separator: " ")
  }

  /// `_LEVEL_LISTING.txt`'s order is the source of truth for level progression, but its titles
  /// don't always match their on-disk filename 1:1 - so every level `.txt` file directly under
  /// `directory` gets parsed once and matched back to the listing by its parsed `[info] title=`.
  /// Matching is case-insensitive: the Undercover level files' own `title=` lines are ALL CAPS
  /// (e.g. `title=BLOW UP`) while `Undercover Exclusive/_LEVEL_LISTING.txt` uses title case
  /// (`Blow Up`) - a real casing mismatch in the level data itself, not a normalization bug (the
  /// top-level Junkbot game's files don't have this mismatch, but Undercover's do, for all but a
  /// handful of entries). The listing's own text is kept as the entry's display title, since
  /// that's what the browser build's level-select list shows.
  private static func loadEntries(directory: URL) -> [LevelCatalogEntry] {
    let fileManager = FileManager.default
    guard
      let files = try? fileManager.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil)
    else { return [] }

    var byTitle: [String: (url: URL, par: Int?)] = [:]
    for url in files where url.pathExtension == "txt" {
      guard let text = readLevelText(at: url) else { continue }
      let level = Level(text: text)
      byTitle[normalizedTitle(level.title).lowercased()] = (url, level.par)
    }

    guard let listingText = readLevelText(at: directory.appendingPathComponent("_LEVEL_LISTING.txt"))
    else { return [] }

    return listingText.split(separator: "\n").compactMap { line in
      let title = normalizedTitle(String(line))
      guard !title.isEmpty, let match = byTitle[title.lowercased()] else { return nil }
      return LevelCatalogEntry(title: title, url: match.url, par: match.par)
    }
  }

  private static func paginate(_ entries: [LevelCatalogEntry]) -> [[LevelCatalogEntry]] {
    stride(from: 0, to: entries.count, by: pageSize).map {
      Array(entries[$0..<min($0 + pageSize, entries.count)])
    }
  }

  /// - Parameter repoRoot: the repo root containing `levels/` (and `levels/Undercover Exclusive/`).
  public init(repoRoot: URL) {
    let junkbotDirectory = repoRoot.appendingPathComponent("levels")
    let undercoverDirectory = junkbotDirectory.appendingPathComponent("Undercover Exclusive")
    pagesByGame = [
      .junkbot: Self.paginate(Self.loadEntries(directory: junkbotDirectory)),
      .junkbotUndercover: Self.paginate(Self.loadEntries(directory: undercoverDirectory)),
    ]
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
  /// `nil` if `title` is the last level (mirrors `goToNextLevel`'s "no next level" branch, which
  /// shows a game-complete screen instead).
  public func nextLevel(after title: String, game: Game) -> LevelCatalogEntry? {
    let flat = (pagesByGame[game] ?? []).flatMap { $0 }
    guard let index = flat.firstIndex(where: { $0.title == title }) else { return nil }
    let nextIndex = flat.index(after: index)
    return nextIndex < flat.endIndex ? flat[nextIndex] : nil
  }
}
#endif
