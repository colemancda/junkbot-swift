import CTRU

/// Bitmap-font renderer for the 3DS top screen (info panel: level title/hint/moves, win/lose
/// prompt) - grey background, drawn with the same proportional bitmap font every other port
/// uses (`font/font.png`, matching `Sources/JunkbotCore/Font.swift`'s layout metrics), but
/// through a build-time-generated ASCII-byte table (`tools/gen_font.py`,
/// `build/FontAssets.swift`) instead of calling into `Font.swift` itself - Character/String
/// operations (even just iterating one) need the Embedded stdlib's grapheme-breaking/
/// case-mapping data tables, which this port would rather not spend code size on (mirrors
/// `ports/NDS`'s identical reasoning), and every string this port actually draws (level
/// titles/hints, baked into `build/LevelAssets.swift` as `StaticString` by `tools/LevelDump`)
/// is plain ASCII anyway.
///
/// Unlike the bottom (world) screen, the top screen is physically 400x240 (not 320x240), so it
/// gets its own canvas/present pair (`topCanvas`/`ctru_present_top`) rather than reusing
/// Renderer.swift's `screenWidth`/`screenHeight`/`canvas`.

let topScreenWidth: Int32 = 400
let topScreenHeight: Int32 = 240

let fontBits: UnsafePointer<UInt8> =
  ctru_asset_font_bin()!.assumingMemoryBound(to: UInt8.self)
let fontRowStride: Int32 = (fontBitmapWidth + 7) / 8

/// RGB555-style grey (converted through the shared RGB565 helper, see Renderer.swift) for the
/// top screen's background fill.
let topScreenBackgroundColor: UInt16 = rgb565(fromRGB555: 0x8000 | (14 << 10) | (14 << 5) | 14)
/// Near-black, for text over that grey.
let topScreenTextColor: UInt16 = rgb565(fromRGB555: 0x8000 | (2 << 10) | (2 << 5) | 2)

/// Persistent top-screen canvas, presented via `ctru_present_top` only when its content
/// actually changes (level load, moves-counter/win-lose update) - see main.swift's
/// `gfxSetDoubleBuffering(GFX_TOP, false)`.
let topCanvas = UnsafeMutablePointer<UInt16>.allocate(capacity: Int(topScreenWidth * topScreenHeight))

func clearTopScreen() {
  topCanvas.update(repeating: topScreenBackgroundColor, count: Int(topScreenWidth * topScreenHeight))
}

/// Repaints a rectangle to the top screen's background color - callers redrawing just a small
/// region (e.g. the moves counter after every move, rather than the whole screen) call this
/// first so a shorter new string doesn't leave stale glyph pixels behind from a longer old one.
func clearRect(x: Int32, y: Int32, width: Int32, height: Int32) {
  var dy: Int32 = 0
  while dy < height {
    let py = y + dy
    if py >= 0, py < topScreenHeight {
      let rowBase = Int(py) * Int(topScreenWidth)
      var dx: Int32 = 0
      while dx < width {
        let px = x + dx
        if px >= 0, px < topScreenWidth {
          topCanvas[rowBase + Int(px)] = topScreenBackgroundColor
        }
        dx += 1
      }
    }
    dy += 1
  }
}

@inline(__always)
private func byteAt(_ text: StaticString, _ index: Int) -> UInt8 {
  UnsafeRawPointer(text.utf8Start).assumingMemoryBound(to: UInt8.self)[index]
}

@inline(__always)
private func glyphOpaque(offset: Int32, dx: Int32, dy: Int32) -> Bool {
  let bitIndex = offset + dx
  let byte = fontBits[Int(dy * fontRowStride + bitIndex / 8)]
  return byte & (0x80 >> UInt8(bitIndex % 8)) != 0
}

/// Pre-scale advance in pixels for one ASCII byte: the glyph's width + 1, or the space-advance
/// constant for bytes with no glyph (matching `Font.layoutText`'s `advance: 6` for `" "` and
/// anything else unmapped).
@inline(__always)
func glyphAdvance(_ byte: UInt8) -> Int32 {
  guard byte < 128 else { return 6 }
  let width = fontAsciiWidthTable[Int(byte)]
  return width >= 0 ? width + 1 : 6
}

func drawChar(_ byte: UInt8, x: Int32, y: Int32, scale: Int32, color: UInt16) {
  guard byte < 128 else { return }
  let offset = fontAsciiOffsetTable[Int(byte)]
  let width = fontAsciiWidthTable[Int(byte)]
  guard offset >= 0, width > 0 else { return }

  var dy: Int32 = 0
  while dy < fontGlyphHeight {
    var dx: Int32 = 0
    while dx < width {
      if glyphOpaque(offset: offset, dx: dx, dy: dy) {
        let blockX = x + dx * scale
        let blockY = y + dy * scale
        var sy: Int32 = 0
        while sy < scale {
          let py = blockY + sy
          if py >= 0, py < topScreenHeight {
            let rowBase = Int(py) * Int(topScreenWidth)
            var sx: Int32 = 0
            while sx < scale {
              let px = blockX + sx
              if px >= 0, px < topScreenWidth {
                topCanvas[rowBase + Int(px)] = color
              }
              sx += 1
            }
          }
          sy += 1
        }
      }
      dx += 1
    }
    dy += 1
  }
}

/// Draws a single line (no wrapping) starting at `(x, y)`. Returns the pen's ending X, so callers
/// can chain a few pieces (e.g. "LEVEL" + a number) on one line.
@discardableResult
func drawText(_ text: StaticString, x: Int32, y: Int32, scale: Int32, color: UInt16) -> Int32 {
  let count = text.utf8CodeUnitCount
  var penX = x
  var i = 0
  while i < count {
    let byte = byteAt(text, i)
    drawChar(byte, x: penX, y: y, scale: scale, color: color)
    penX += glyphAdvance(byte) * scale
    i += 1
  }
  return penX
}

/// Draws `text` starting at `(x, y)`, wrapping onto additional lines (advancing Y) whenever the
/// next word would exceed `maxWidth` - only ever breaks at a space, never mid-word. Returns the Y
/// position just below the last line drawn.
@discardableResult
func drawWrappedText(
  _ text: StaticString, x: Int32, y: Int32, maxWidth: Int32, scale: Int32, color: UInt16
) -> Int32 {
  let count = text.utf8CodeUnitCount
  let lineHeight = (fontGlyphHeight + 3) * scale
  var penX = x
  var penY = y
  var index = 0
  while index < count {
    var wordEnd = index
    while wordEnd < count, byteAt(text, wordEnd) != 0x20 { wordEnd += 1 }

    var wordWidth: Int32 = 0
    var i = index
    while i < wordEnd {
      wordWidth += glyphAdvance(byteAt(text, i)) * scale
      i += 1
    }

    if penX > x, penX + wordWidth > x + maxWidth {
      penX = x
      penY += lineHeight
    }
    i = index
    while i < wordEnd {
      let byte = byteAt(text, i)
      drawChar(byte, x: penX, y: penY, scale: scale, color: color)
      penX += glyphAdvance(byte) * scale
      i += 1
    }
    if wordEnd < count {
      penX += glyphAdvance(0x20) * scale  // consume the separating space
      wordEnd += 1
    }
    index = wordEnd
  }
  return penY + lineHeight
}

/// Draws a non-negative integer (moves/par/level counters - never negative in this game).
/// Returns the pen's ending X.
@discardableResult
func drawInt(_ value: Int32, x: Int32, y: Int32, scale: Int32, color: UInt16) -> Int32 {
  var digits: [UInt8] = []
  var v = max(value, 0)
  repeat {
    digits.append(UInt8(0x30 + v % 10))
    v /= 10
  } while v > 0
  var penX = x
  for byte in digits.reversed() {
    drawChar(byte, x: penX, y: y, scale: scale, color: color)
    penX += glyphAdvance(byte) * scale
  }
  return penX
}
