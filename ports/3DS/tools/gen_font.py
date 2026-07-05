#!/usr/bin/env python3
"""Build-time bitmap-font converter for the Nintendo 3DS port's top screen.

`font/font.png` (374x5px, 4-bit palette) is the same proportional bitmap font
`Sources/JunkbotCore/Font.swift` describes (`characters`/`characterWidths`/
`characterOffsets`/`characterHeight`) and every other native port draws with
- a single row of white-on-transparent glyphs meant to be color-tinted at
draw time. This script packs it into an ASCII-byte-indexed table instead of
reusing `Font.swift`'s `[Character]`-keyed API directly: Swift `Character`/
`String` operations (even just iterating or hashing them) need the Embedded
stdlib's grapheme-breaking/case-mapping data tables, which cost real code
size this port would rather not spend (mirrors `ports/NDS`'s identical
reasoning, where the tables also blow the DS's tighter ROM budget outright).
Every string this port actually draws (level titles/hints, both baked into
`build/LevelAssets.swift` by `tools/LevelDump`) is plain ASCII, so an
ASCII-byte table (with lowercase folded to the atlas's uppercase-only
glyphs, matching `Font.layoutText`'s `.uppercased()`) covers everything
needed with no runtime String involved at all - see `source/TextRenderer.swift`.

Emits:
  <out>/font.bin        -- the atlas as a 1-bit-per-pixel bitmap (row-major,
                            MSB-first, 1 = opaque), tiny (~234 bytes).
  <out>/FontAssets.swift -- 128-entry ASCII -> (offset, width) tables (width
                            -1 = no glyph for this byte).

Usage: gen_font.py <repo_root> <out_dir>
"""

import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gen_assets import decode_png  # noqa: E402 - reuse the shared PNG decoder

# Mirrors Sources/JunkbotCore/Font.swift's `characters` order exactly. Entries
# that aren't a single ASCII byte (the smiley/replacement-char/accented
# glyphs at the end) are skipped - see module docstring.
CHARACTERS = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
    "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
    "U", "V", "W", "X", "Y", "Z", "1", "2", "3", "4",
    "5", "6", "7", "8", "9", "0", "?", "!", "(", ")",
    ",", "'", ":", "\"", "-", "+", ".", "^", "@", "#",
    "$", "%", "*", "~", "`", "&", "_", "=", ";", "|",
    "\\", "/", "<", ">", "[", "]", "{", "}", "☺", "�",
    "Ä", "Ö", "Ü", "ẞ",
]

# Mirrors Font.swift's `characterWidths` exactly (same order as CHARACTERS).
CHARACTER_WIDTHS = [
    5, 5, 5, 5, 5, 5, 5, 5, 3, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 3, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 1, 2, 2,
    1, 1, 1, 3, 3, 3, 1, 3, 5, 5, 3, 5, 3, 5, 2, 5, 5, 3, 1, 1,
    5, 5, 3, 3, 2, 2, 3, 3, 5, 5, 5, 5, 5, 5,
]

CHARACTER_HEIGHT = 5


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: gen_font.py <repo_root> <out_dir>")
    repo_root = Path(sys.argv[1]).resolve()
    out_dir = Path(sys.argv[2]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    # font.png is a 4-bit-palette PNG; decode_png only handles 8-bit depths,
    # so re-encode via macOS's `sips` first (same approach as tools/gen_audio.py
    # shelling out to `afconvert` - this build already requires macOS).
    with tempfile.TemporaryDirectory() as tmp:
        png8 = Path(tmp) / "font8.png"
        subprocess.run(
            ["sips", "-s", "format", "png", str(repo_root / "font/font.png"), "--out", str(png8)],
            check=True, capture_output=True)
        width, height, pixels = decode_png(png8)
    if height != CHARACTER_HEIGHT:
        raise SystemExit(f"error: font/font.png is {height}px tall, expected {CHARACTER_HEIGHT}")

    # Pack to 1bpp, row-major, MSB-first per byte.
    stride = (width + 7) // 8
    bitmap = bytearray(stride * height)
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[y * width + x]
            if a >= 128:
                bitmap[y * stride + (x // 8)] |= 0x80 >> (x % 8)

    offsets = []
    x = 0
    for w in CHARACTER_WIDTHS:
        offsets.append(x)
        x += w + 1

    # ASCII byte -> (offset, width), lowercase folded onto the same glyph as
    # its uppercase letter (the atlas only has uppercase, matching
    # Font.layoutText's `.uppercased()` - see module docstring for why this
    # port can't just call that instead).
    ascii_offset = [-1] * 128
    ascii_width = [-1] * 128
    for char, offset, cwidth in zip(CHARACTERS, offsets, CHARACTER_WIDTHS):
        if len(char) != 1 or ord(char) > 127:
            continue
        codes = [ord(char)]
        if char.isalpha():
            codes = [ord(char.upper()), ord(char.lower())]
        for code in codes:
            ascii_offset[code] = offset
            ascii_width[code] = cwidth

    (out_dir / "font.bin").write_bytes(bitmap)

    def swift_int_array(name, values):
        lines = ",\n  ".join(
            ", ".join(str(v) for v in values[i : i + 16]) for i in range(0, len(values), 16))
        return f"let {name}: [Int32] = [\n  {lines},\n]\n"

    (out_dir / "FontAssets.swift").write_text(
        "// Generated by ports/3DS/tools/gen_font.py - do not edit.\n"
        "\n"
        "/// `font/font.png`'s pixel width/height (the atlas is a single row of glyphs).\n"
        f"let fontBitmapWidth: Int32 = {width}\n"
        f"let fontGlyphHeight: Int32 = {height}\n"
        "\n"
        "/// Byte offset/width of the glyph for ASCII code point `n` within the\n"
        "/// `font.bin` bitmap row, or -1 for a code point with no glyph (draw nothing,\n"
        "/// caller decides the advance - `source/TextRenderer.swift` uses Font.swift's\n"
        "/// own space-advance constant). Lowercase letters fold onto their uppercase\n"
        "/// glyph, matching every other port's `.uppercased()` display.\n"
        f"{swift_int_array('fontAsciiOffsetTable', ascii_offset)}"
        f"{swift_int_array('fontAsciiWidthTable', ascii_width)}"
    )
    covered = sum(1 for w in ascii_width if w >= 0)
    print(f"font.bin: {width}x{height} atlas, {len(bitmap)} bytes, {covered}/128 ASCII glyphs")


if __name__ == "__main__":
    main()
