import Testing

@testable import JunkbotCore

@Suite("Bitmap font layout")
struct FontTests {

  @Test("Metrics tables are 74 entries, matching src/game.js's fontChars/fontCharW exactly")
  func metricsTableSizes() {
    #expect(Font.characters.count == 74)
    #expect(Font.characterWidths.count == 74)
    #expect(Font.characterOffsets.count == 74)
  }

  @Test("Character offsets are cumulative widths plus one pixel of spacing")
  func offsetsAreCumulative() {
    #expect(Font.characterOffsets[0] == 0)
    for i in 1..<Font.characterOffsets.count {
      #expect(Font.characterOffsets[i] == Font.characterOffsets[i - 1] + Font.characterWidths[i - 1] + 1)
    }
  }

  @Test("Laying out \"AB\" places two glyphs back to back")
  func simpleLayout() {
    let placements = Font.layoutText("AB")
    #expect(placements.count == 2)
    #expect(placements[0].atlasIndex == 0)  // 'A'
    #expect(placements[0].x == 0)
    #expect(placements[1].atlasIndex == 1)  // 'B'
    #expect(placements[1].x == Font.characterWidths[0] + 1)
  }

  @Test("Lowercase input is uppercased before layout")
  func lowercaseIsUppercased() {
    let placements = Font.layoutText("a")
    #expect(placements.count == 1)
    #expect(placements[0].atlasIndex == 0)  // 'A'
  }

  @Test("A space advances the pen without a glyph")
  func spaceAdvancesWithNoGlyph() {
    let placements = Font.layoutText("A B")
    #expect(placements.count == 3)
    #expect(placements[0].atlasIndex == 0)  // 'A'
    #expect(placements[1].atlasIndex == nil)  // ' '
    #expect(placements[1].advance == 6)
    #expect(placements[2].x == placements[0].advance + placements[1].advance)
  }

  @Test("A newline resets x and advances y by characterHeight + 4")
  func newlineWrapsLine() {
    let placements = Font.layoutText("A\nB")
    #expect(placements.count == 2)
    #expect(placements[0].y == 0)
    #expect(placements[1].x == 0)
    #expect(placements[1].y == Font.characterHeight + 4)
  }

  @Test("An unrecognized character falls back to the replacement glyph")
  func unrecognizedCharacterFallsBack() {
    let placements = Font.layoutText("\u{2603}")  // snowman, not in the atlas
    #expect(placements.count == 1)
    #expect(placements[0].atlasIndex == Font.characters.firstIndex(of: "\u{FFFD}"))
  }
}
