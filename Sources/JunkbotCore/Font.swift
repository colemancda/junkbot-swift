/// Bitmap font metrics + text layout, ported verbatim from `src/game.js`'s `fontChars`/
/// `fontCharW`/`fontCharX`/`fontCharHeight`/`drawText` (the layout half only - actual drawing is
/// backend-specific: JS composites pre-tinted canvases, a native renderer can just
/// color-modulate one texture per glyph draw). No Foundation dependency, so this is usable from
/// the embedded-WASM target too, even though `src/game.js` has no reason to consume it (it
/// already has its own working copy) - this exists for `JunkbotSDL3` and any future native
/// renderer.
public enum Font {
  /// One row of glyphs in `font/font.png`, left to right, matching `fontChars` in game.js.
  public static let characters = Array(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890?!(),':\"-+.^@#$%*~`&_=;|\\/<>[]{}\u{263A}\u{FFFD}ÄÖÜẞ")

  /// Per-glyph pixel width, matching `fontCharW` (digit string, `_` = 10, decoded once here
  /// rather than at every call site).
  public static let characterWidths: [Int32] = {
    "555555553555555555555555553555555555512211133313553535_255311_55332233555555"
      .map { $0 == "_" ? 10 : Int32(String($0))! }
  }()

  /// Cumulative x-offset of each glyph within `font/font.png`, matching `fontCharX`.
  public static let characterOffsets: [Int32] = {
    var offsets: [Int32] = []
    offsets.reserveCapacity(characterWidths.count)
    var x: Int32 = 0
    for width in characterWidths {
      offsets.append(x)
      x += width + 1
    }
    return offsets
  }()

  /// Glyph height in `font/font.png`, matching `fontCharHeight`.
  public static let characterHeight: Int32 = 5

  private static var indexByCharacter: [Character: Int] = {
    var map: [Character: Int] = [:]
    for (index, char) in characters.enumerated() where map[char] == nil {
      map[char] = index
    }
    return map
  }()

  /// One glyph's placement within a line of laid-out text: which glyph (`atlasIndex`, an index
  /// into `characters`/`characterWidths`/`characterOffsets`), the pen position to draw it at,
  /// and how far to advance the pen afterward. `atlasIndex == nil` means a blank advance (a
  /// space or unrecognized character with no glyph to draw).
  public struct GlyphPlacement: Equatable, Sendable {
    public let atlasIndex: Int?
    public let x: Int32
    public let y: Int32
    public let advance: Int32
  }

  /// Lays out `text` starting at `(0, 0)`, uppercased (the atlas only has uppercase glyphs,
  /// matching `drawText`'s `text.toUpperCase()`), advancing `y` by `characterHeight + 4` per
  /// `\n` - matches `drawText`'s layout loop, minus the actual drawing. Unrecognized characters
  /// fall back to the atlas's replacement-character glyph (`\u{FFFD}`), matching `drawText`.
  public static func layoutText(_ text: String) -> [GlyphPlacement] {
    var placements: [GlyphPlacement] = []
    var x: Int32 = 0
    var y: Int32 = 0
    for char in text.uppercased() {
      if char == " " {
        placements.append(GlyphPlacement(atlasIndex: nil, x: x, y: y, advance: 6))
        x += 6
        continue
      }
      if char == "\n" {
        x = 0
        y += characterHeight + 4
        continue
      }
      let index = indexByCharacter[char] ?? indexByCharacter["\u{FFFD}"]
      guard let index else { continue }
      let advance = characterWidths[index] + 1
      placements.append(GlyphPlacement(atlasIndex: index, x: x, y: y, advance: advance))
      x += advance
    }
    return placements
  }
}
