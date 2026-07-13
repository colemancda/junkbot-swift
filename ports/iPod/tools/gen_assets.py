#!/usr/bin/env python3
"""Build-time asset generator for the Nintendo 3DS port.

Reads the repo's canonical sprite tables (Sources/JunkbotCore/Generated/
SpriteTable.swift) and emits:

  <out>/sprites.bin        -- every sprite-sheet frame (sprites, undercover
                              sprites, AND both background sheets -- unlike
                              the DS port, the 3DS's RAM budget doesn't force
                              skipping backgrounds) as one little-endian
                              UInt16 per pixel: bit15 set + RGB555 for an
                              opaque pixel, 0 for transparent. No shared
                              palette (and so no 255-color cap) since each
                              pixel stores its own color directly.
  <out>/SpriteAssets.swift -- per-sprite-ID UInt16 *element* offset into
                              sprites.bin (-1 = no pixel data: gap slot),
                              plus... nothing else. Frame dimensions come
                              from the core's shared spriteWidthTable/
                              spriteHeightTable.

(Levels are converted separately by tools/LevelDump, a host-side Swift tool
that runs the real JunkbotCore parser.) Pure stdlib (zlib-based PNG decoding)
so the build needs no pip installs.
"""

import re
import struct
import sys
import zlib
from pathlib import Path

# ---------------------------------------------------------------------------
# Minimal PNG decoder (8-bit RGB / RGBA / palette, non-interlaced -- all this
# repo's sprites are color type 2 or 6; type 3 supported for safety).
# ---------------------------------------------------------------------------


def decode_png(path):
    """Returns (width, height, pixels) with pixels a flat list of (r,g,b,a)."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG")
    pos = 8
    width = height = None
    bit_depth = color_type = interlace = None
    idat = bytearray()
    palette = []
    trns = b""
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        ctype = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", body
            )
        elif ctype == b"PLTE":
            palette = [tuple(body[i : i + 3]) for i in range(0, len(body), 3)]
        elif ctype == b"tRNS":
            trns = body
        elif ctype == b"IDAT":
            idat += body
        elif ctype == b"IEND":
            break
    if bit_depth != 8 or color_type not in (2, 3, 6):
        raise ValueError(f"{path}: unsupported PNG (depth {bit_depth}, type {color_type})")
    if interlace != 0:
        raise ValueError(f"{path}: interlaced PNGs not supported")

    channels = {2: 3, 3: 1, 6: 4}[color_type]
    stride = width * channels
    raw = zlib.decompress(bytes(idat))

    # Un-filter scanlines (filter types 0-4).
    out = bytearray(height * stride)
    prev_row_start = None
    pos = 0
    for y in range(height):
        ftype = raw[pos]
        pos += 1
        row_start = y * stride
        line = raw[pos : pos + stride]
        pos += stride
        if ftype == 0:
            out[row_start : row_start + stride] = line
        elif ftype == 1:  # Sub
            for i in range(stride):
                left = out[row_start + i - channels] if i >= channels else 0
                out[row_start + i] = (line[i] + left) & 0xFF
        elif ftype == 2:  # Up
            for i in range(stride):
                up = out[prev_row_start + i] if prev_row_start is not None else 0
                out[row_start + i] = (line[i] + up) & 0xFF
        elif ftype == 3:  # Average
            for i in range(stride):
                left = out[row_start + i - channels] if i >= channels else 0
                up = out[prev_row_start + i] if prev_row_start is not None else 0
                out[row_start + i] = (line[i] + ((left + up) >> 1)) & 0xFF
        elif ftype == 4:  # Paeth
            for i in range(stride):
                a = out[row_start + i - channels] if i >= channels else 0
                b = out[prev_row_start + i] if prev_row_start is not None else 0
                c = (
                    out[prev_row_start + i - channels]
                    if prev_row_start is not None and i >= channels
                    else 0
                )
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                out[row_start + i] = (line[i] + pred) & 0xFF
        else:
            raise ValueError(f"{path}: bad filter type {ftype}")
        prev_row_start = row_start

    pixels = []
    if color_type == 6:
        for i in range(0, len(out), 4):
            pixels.append((out[i], out[i + 1], out[i + 2], out[i + 3]))
    elif color_type == 2:
        for i in range(0, len(out), 3):
            pixels.append((out[i], out[i + 1], out[i + 2], 255))
    else:  # palette
        for i in range(len(out)):
            r, g, b = palette[out[i]]
            a = trns[out[i]] if out[i] < len(trns) else 255
            pixels.append((r, g, b, a))
    return width, height, pixels


# ---------------------------------------------------------------------------
# SpriteTable.swift parsing
# ---------------------------------------------------------------------------


def parse_swift_string_array(source, name):
    body = re.search(
        rf"let {name}: \[StaticString\] = \[(.*?)\]", source, re.DOTALL
    ).group(1)
    return re.findall(r'"([^"]*)"', body)


def parse_swift_int_array(source, name):
    body = re.search(rf"let {name}: \[Int32\] = \[(.*?)\]", source, re.DOTALL).group(1)
    return [int(t) for t in re.findall(r"-?\d+", body)]


SHEET_DIRS = {
    0: "images/sprites",
    1: "images/sprites/Undercover Exclusive",
    2: "images/backgrounds",
    3: "images/backgrounds/Undercover Exclusive",
}


def generate_sprites(repo_root, out_dir):
    table_source = (
        repo_root / "Sources/JunkbotCore/Generated/SpriteTable.swift"
    ).read_text()
    names = parse_swift_string_array(table_source, "spriteNameTable")
    sheets = parse_swift_int_array(table_source, "spriteSheetTable")
    widths = parse_swift_int_array(table_source, "spriteWidthTable")
    heights = parse_swift_int_array(table_source, "spriteHeightTable")
    assert len(names) == len(sheets) == len(widths) == len(heights)

    blob = bytearray()
    offsets = []  # UInt16 *element* offsets, -1 for gap slots
    converted = 0
    for sprite_id, name in enumerate(names):
        sheet = sheets[sprite_id]
        if not name or sheet not in SHEET_DIRS:
            offsets.append(-1)
            continue
        png = repo_root / SHEET_DIRS[sheet] / f"{name}.png"
        if not png.exists():
            print(f"warning: missing sprite image {png}", file=sys.stderr)
            offsets.append(-1)
            continue
        width, height, pixels = decode_png(png)
        if width != widths[sprite_id] or height != heights[sprite_id]:
            raise SystemExit(
                f"error: {png} is {width}x{height} but SpriteTable.swift says "
                f"{widths[sprite_id]}x{heights[sprite_id]} -- rerun `make codegen`?"
            )
        offsets.append(len(blob) // 2)
        for r, g, b, a in pixels:
            if a < 128:
                blob += struct.pack("<H", 0)
            else:
                rgb555 = 0x8000 | ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)
                blob += struct.pack("<H", rgb555)
        converted += 1

    (out_dir / "sprites.bin").write_bytes(blob)
    lines = ",\n  ".join(
        ", ".join(str(o) for o in offsets[i : i + 12]) for i in range(0, len(offsets), 12)
    )
    (out_dir / "SpriteAssets.swift").write_text(
        "// Generated by ports/3DS/tools/gen_assets.py - do not edit.\n"
        "\n"
        "/// UInt16 *element* offset of each sprite ID's pixel data within\n"
        "/// `sprites.bin` (one little-endian UInt16 per pixel: bit15 set + RGB555\n"
        "/// for opaque, 0 for transparent), or -1 for a gap slot with no art.\n"
        "/// Frame dimensions come from the core's `spriteWidthTable`/`spriteHeightTable`.\n"
        f"let spriteDataOffsetTable: [Int32] = [\n  {lines},\n]\n"
    )
    print(
        f"sprites.bin: {converted} frames, {len(blob)} bytes "
        f"({len(blob) / 1024 / 1024:.2f} MB)"
    )


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: gen_assets.py <repo_root> <out_dir>")
    repo_root = Path(sys.argv[1]).resolve()
    out_dir = Path(sys.argv[2]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    generate_sprites(repo_root, out_dir)


if __name__ == "__main__":
    main()
