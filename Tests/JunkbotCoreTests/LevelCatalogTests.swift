import Foundation
import Testing

@testable import JunkbotCore

@Suite("Level catalog")
struct LevelCatalogTests {

  /// Repo root, resolved from this file's own path, matching `LevelTests.repoRoot`.
  static var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  @Test("Junkbot's 60 levels paginate into four 15-level pages")
  func junkbotPagination() {
    let catalog = LevelCatalog(repoRoot: Self.repoRoot)
    let pages = catalog.pagesByGame[.junkbot] ?? []
    #expect(pages.count == 4)
    for page in pages {
      #expect(page.count == 15)
    }
    #expect(pages.flatMap { $0 }.count == 60)
  }

  @Test("Undercover's 61 levels paginate into four full pages plus a trailing partial page")
  func undercoverPagination() {
    let catalog = LevelCatalog(repoRoot: Self.repoRoot)
    let pages = catalog.pagesByGame[.junkbotUndercover] ?? []
    #expect(pages.count == 5)
    for page in pages.dropLast() {
      #expect(page.count == 15)
    }
    #expect(pages.last?.count == 1)
    #expect(pages.flatMap { $0 }.count == 61)
  }

  @Test("location(ofLevelTitled:) finds the first and last levels of the first page")
  func locationAtPageBoundaries() {
    let catalog = LevelCatalog(repoRoot: Self.repoRoot)
    let firstPage = catalog.pagesByGame[.junkbot]?.first ?? []
    #expect(firstPage.count == 15)

    let first = catalog.location(ofLevelTitled: firstPage[0].title, game: .junkbot)
    #expect(first?.page == 0)
    #expect(first?.indexInPage == 0)

    let last = catalog.location(ofLevelTitled: firstPage[14].title, game: .junkbot)
    #expect(last?.page == 0)
    #expect(last?.indexInPage == 14)

    #expect(catalog.location(ofLevelTitled: "Not A Real Level", game: .junkbot) == nil)
  }

  @Test("nextLevel(after:) crosses page boundaries and returns nil after the last level")
  func nextLevelCrossesPages() {
    let catalog = LevelCatalog(repoRoot: Self.repoRoot)
    let pages = catalog.pagesByGame[.junkbot] ?? []
    let lastOfFirstPage = pages[0][14]
    let firstOfSecondPage = pages[1][0]

    let next = catalog.nextLevel(after: lastOfFirstPage.title, game: .junkbot)
    #expect(next?.title == firstOfSecondPage.title)

    let veryLast = pages.last!.last!
    #expect(catalog.nextLevel(after: veryLast.title, game: .junkbot) == nil)
  }

  @Test("Every catalog entry's par matches the level file's own [info] par")
  func parIsCarriedThrough() throws {
    let catalog = LevelCatalog(repoRoot: Self.repoRoot)
    let entry = try #require(catalog.pagesByGame[.junkbot]?.first?.first)
    let text = try String(contentsOf: entry.url, encoding: .utf8)
    let level = Level(text: text)
    #expect(entry.par == level.par)
  }
}
