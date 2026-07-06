import CN64

/// Bitmap-font renderer for the N64's HUD overlay (level number, moves counter,
/// win/lose prompt), drawn directly on top of the game world in the same
/// framebuffer -- unlike ports/3DS/ports/NDS, the N64 has only one screen, so
/// there's no separate text-console surface. Uses the same build-time-generated
/// ASCII-byte glyph table as ports/NDS (tools/gen_font.py, copied verbatim):
/// Character/String operations (even just iterating one) need the Embedded
/// stdlib's grapheme-breaking/case-mapping data tables, which this ROM's budget
/// can't spare, and every string this port actually draws (level titles/hints,
/// baked into build/LevelAssets.swift as StaticString by tools/LevelDump) is
/// plain ASCII anyway.

let fontBits: UnsafePointer<UInt8> =
  n64_asset_font_bin()!.assumingMemoryBound(to: UInt8.self)
let fontRowStride: Int32 = (fontBitmapWidth + 7) / 8

/// Near-black HUD text over the game world, opaque in the N64's native 5551 format.
let hudTextColor: UInt16 = packRGBA5551(fromBGR555: (2 << 10) | (2 << 5) | 2)
/// Light grey HUD background strip.
let hudBackgroundColor: UInt16 = packRGBA5551(fromBGR555: (28 << 10) | (28 << 5) | 28)

/// Repaints a rectangle to the HUD background color - callers redrawing just a
/// small region (e.g. the moves counter after every move) call this first so a
/// shorter new string doesn't leave stale glyph pixels behind from a longer old one.
func clearRect(x: Int32, y: Int32, width: Int32, height: Int32, strideElements: Int32, into buffer: UnsafeMutablePointer<UInt16>) {
  var dy: Int32 = 0
  while dy < height {
    let py = y + dy
    if py >= 0, py < screenHeight {
      let rowBase = Int(py) * Int(strideElements)
      var dx: Int32 = 0
      while dx < width {
        let px = x + dx
        if px >= 0, px < screenWidth {
          buffer[rowBase + Int(px)] = hudBackgroundColor
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

func drawChar(
  _ byte: UInt8, x: Int32, y: Int32, scale: Int32, color: UInt16, strideElements: Int32,
  into buffer: UnsafeMutablePointer<UInt16>
) {
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
          if py >= 0, py < screenHeight {
            let rowBase = Int(py) * Int(strideElements)
            var sx: Int32 = 0
            while sx < scale {
              let px = blockX + sx
              if px >= 0, px < screenWidth {
                buffer[rowBase + Int(px)] = color
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
func drawText(
  _ text: StaticString, x: Int32, y: Int32, scale: Int32, color: UInt16, strideElements: Int32,
  into buffer: UnsafeMutablePointer<UInt16>
) -> Int32 {
  let count = text.utf8CodeUnitCount
  var penX = x
  var i = 0
  while i < count {
    let byte = byteAt(text, i)
    drawChar(byte, x: penX, y: y, scale: scale, color: color, strideElements: strideElements, into: buffer)
    penX += glyphAdvance(byte) * scale
    i += 1
  }
  return penX
}

/// Draws a non-negative integer (moves/par/level counters - never negative in this game).
/// Returns the pen's ending X.
@discardableResult
func drawInt(
  _ value: Int32, x: Int32, y: Int32, scale: Int32, color: UInt16, strideElements: Int32,
  into buffer: UnsafeMutablePointer<UInt16>
) -> Int32 {
  var digits: [UInt8] = []
  var v = max(value, 0)
  repeat {
    digits.append(UInt8(0x30 + v % 10))
    v /= 10
  } while v > 0
  var penX = x
  for byte in digits.reversed() {
    drawChar(byte, x: penX, y: y, scale: scale, color: color, strideElements: strideElements, into: buffer)
    penX += glyphAdvance(byte) * scale
  }
  return penX
}
