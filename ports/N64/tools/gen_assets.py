#!/usr/bin/env python3
"""Build-time asset generator for the Nintendo N64 port.

Reads the repo's canonical sprite tables (Sources/JunkbotCore/Generated/
SpriteTable.swift) and emits:

  <out>/sprites.bin        -- every sprite-sheet frame (sheets 0/1 only;
                              backgrounds are deliberately skipped: even at
                              8bpp they'd double the ROM's RAM footprint) as
                              8bpp palette indices (0 = transparent), one
                              byte per pixel, concatenated in sprite-ID
                              order. The whole art set is only ~90 unique
                              RGB555 colors, so 8bpp is lossless.
  <out>/SpriteAssets.swift -- per-sprite-ID byte offsets into sprites.bin
                              (-1 = no pixel data: gap slot or background),
                              plus the shared RGB555 palette.

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
    # 2/3 (backgrounds) intentionally omitted -- see module docstring.
}

# Background images still get a build-time *average color* so the DS renderer
# can clear the screen to something backdrop-ish instead of drawing them.
BACKGROUND_SHEET_DIRS = {
    2: "images/backgrounds",
    3: "images/backgrounds/Undercover Exclusive",
}


def average_rgb15(path):
    """Average opaque-pixel color as N64 palette RGB555 (bit15 set), or 0 if none."""
    _, _, pixels = decode_png(path)
    total_r = total_g = total_b = count = 0
    for r, g, b, a in pixels:
        if a >= 128:
            total_r += r
            total_g += g
            total_b += b
            count += 1
    if count == 0:
        return 0
    r, g, b = total_r // count, total_g // count, total_b // count
    return 0x8000 | ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3)


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
    offsets = []
    averages = []
    palette = {}  # rgb555 -> index (1-based; 0 = transparent)
    converted = 0
    for sprite_id, name in enumerate(names):
        sheet = sheets[sprite_id]
        if name and sheet in BACKGROUND_SHEET_DIRS:
            png = repo_root / BACKGROUND_SHEET_DIRS[sheet] / f"{name}.png"
            averages.append(average_rgb15(png) if png.exists() else 0)
        else:
            averages.append(0)
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
        offsets.append(len(blob))
        for r, g, b, a in pixels:
            if a < 128:
                blob.append(0)
            else:
                rgb15 = 0x8000 | ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3)
                index = palette.setdefault(rgb15, len(palette) + 1)
                blob.append(index)
        converted += 1

    if len(palette) > 255:
        raise SystemExit(
            f"error: sprite art needs {len(palette)} colors; the 8bpp format "
            "allows 255 -- add quantization to gen_assets.py"
        )

    (out_dir / "sprites.bin").write_bytes(blob)
    palette_entries = [0] + [rgb for rgb, _ in sorted(palette.items(), key=lambda kv: kv[1])]
    palette_lines = ",\n  ".join(
        ", ".join(f"0x{c:04X}" for c in palette_entries[i : i + 12])
        for i in range(0, len(palette_entries), 12)
    )
    lines = ",\n  ".join(
        ", ".join(str(o) for o in offsets[i : i + 12]) for i in range(0, len(offsets), 12)
    )
    avg_lines = ",\n  ".join(
        ", ".join(f"0x{a:04X}" for a in averages[i : i + 12])
        for i in range(0, len(averages), 12)
    )
    (out_dir / "SpriteAssets.swift").write_text(
        "// Generated by ports/N64/tools/gen_assets.py - do not edit.\n"
        "\n"
        "/// Byte offset of each sprite ID's 8bpp palette-index pixel data within\n"
        "/// `sprites.bin`, or -1 for IDs with no on-DS pixel data (gap slots and\n"
        "/// background-sheet images, which don't fit in N64 RDRAM). Frame dimensions come\n"
        "/// from the core's `spriteWidthTable`/`spriteHeightTable`.\n"
        f"let spriteDataOffsetTable: [Int32] = [\n  {lines},\n]\n"
        "\n"
        "/// The shared sprite palette: index -> N64 palette RGB555 (bit15 set). Index 0 is\n"
        "/// transparent (never written by a blit); the art set is small enough that\n"
        "/// this palette is exact, not quantized.\n"
        f"let spritePaletteTable: [UInt16] = [\n  {palette_lines},\n]\n"
        "\n"
        "/// Average opaque-pixel color (N64 palette RGB555, bit15 set) of each\n"
        "/// backgrounds-sheet image, 0 for every other sprite ID. The renderer\n"
        "/// clears the screen to the backdrop's average since the full-size\n"
        "/// background images don't fit in N64 RDRAM.\n"
        f"let spriteAverageColorTable: [UInt16] = [\n  {avg_lines},\n]\n"
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
