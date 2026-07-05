#!/usr/bin/env python3
"""Build-time backdrop converter for the Nintendo DS port.

`Renderer.swift` used to skip room backdrops entirely (see ports/NDS/README.md's "Why sprites
but not backgrounds") and just clear the screen to each backdrop's average color - the full-size
artwork alone would roughly double the ARM9 image's ~2.48MB budget. But the five room backdrops
(`images/backgrounds/bkg1..5.png`, 536x420) turn out to be extremely simple flat-shaded art -
only ~10 unique colors each - so a heavily downscaled copy (nearest-neighbor, same exact
per-image palette, no quantization needed) is tiny: at 160x125 each, all five together are under
~100KB, comfortably inside the ROM's remaining headroom. The renderer then upscales back to the
level's actual bounds per pixel at draw time (nearest-neighbor sampling - see
`blitBackdrop` in Renderer.swift) - blocky compared to the original, but real recognizable art
instead of a flat tint.

Emits:
  <out>/backdrops.bin        -- every downscaled backdrop's 8bpp palette-index pixels,
                                 concatenated in sprite-ID order.
  <out>/BackdropAssets.swift -- per-sprite-ID (offset, width, height) into backdrops.bin
                                 (-1 offset = no backdrop data for that ID) plus each
                                 backdrop's own small RGB555 palette, concatenated with an
                                 offset/count per entry.

Usage: gen_backdrops.py <repo_root> <out_dir>
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gen_assets import decode_png, parse_swift_string_array, parse_swift_int_array  # noqa: E402

# Linear downscale factor applied to every backdrop (536x420 -> ~160x125).
SCALE = 160 / 536

# Only the five actual room backdrops (bkg1..bkg5 on the Junkbot background sheet) - NOT every
# image on that sheet, which also holds ~80 small decal images (arrows, doors, pipes, ...)
# `backgroundDecals`/`decals` reference. Those stay unembedded: this port still doesn't render
# decals (see ports/NDS/README.md), only the room backdrop itself. Sheet 3 (Undercover
# Exclusive's backgrounds) is skipped too - this v1 port doesn't ship that campaign at all.
BACKDROP_SHEET = 2
BACKDROP_DIR = "images/backgrounds"
BACKDROP_NAME_PATTERN = re.compile(r"^bkg\d+$")


def downscale_nearest(width, height, pixels, scale):
    new_w = max(1, round(width * scale))
    new_h = max(1, round(height * scale))
    out = []
    for y in range(new_h):
        src_y = min(height - 1, int(y / scale))
        row_base = src_y * width
        for x in range(new_w):
            src_x = min(width - 1, int(x / scale))
            out.append(pixels[row_base + src_x])
    return new_w, new_h, out


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: gen_backdrops.py <repo_root> <out_dir>")
    repo_root = Path(sys.argv[1]).resolve()
    out_dir = Path(sys.argv[2]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    table_source = (
        repo_root / "Sources/JunkbotCore/Generated/SpriteTable.swift"
    ).read_text()
    names = parse_swift_string_array(table_source, "spriteNameTable")
    sheets = parse_swift_int_array(table_source, "spriteSheetTable")

    blob = bytearray()
    offsets = []
    widths = []
    heights = []
    palette_offsets = []
    palette_counts = []
    palette_blob = []
    converted = 0

    for sprite_id, name in enumerate(names):
        sheet = sheets[sprite_id]
        if not name or sheet != BACKDROP_SHEET or not BACKDROP_NAME_PATTERN.match(name):
            offsets.append(-1)
            widths.append(0)
            heights.append(0)
            palette_offsets.append(-1)
            palette_counts.append(0)
            continue
        png = repo_root / BACKDROP_DIR / f"{name}.png"
        if not png.exists():
            offsets.append(-1)
            widths.append(0)
            heights.append(0)
            palette_offsets.append(-1)
            palette_counts.append(0)
            continue

        width, height, pixels = decode_png(png)
        new_w, new_h, small_pixels = downscale_nearest(width, height, pixels, SCALE)

        palette = {}  # rgb555 -> index (0-based; no transparency needed, backdrops are opaque)
        indices = bytearray(len(small_pixels))
        for i, (r, g, b, a) in enumerate(small_pixels):
            rgb15 = 0x8000 | ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3)
            index = palette.setdefault(rgb15, len(palette))
            indices[i] = index
        if len(palette) > 255:
            raise SystemExit(f"error: {png} needs {len(palette)} colors after downscale (>255)")

        offsets.append(len(blob))
        widths.append(new_w)
        heights.append(new_h)
        palette_offsets.append(len(palette_blob))
        palette_counts.append(len(palette))
        palette_blob.extend(rgb for rgb, _ in sorted(palette.items(), key=lambda kv: kv[1]))
        blob += indices
        converted += 1

    (out_dir / "backdrops.bin").write_bytes(blob)

    def int_array(name, values):
        lines = ",\n  ".join(
            ", ".join(str(v) for v in values[i : i + 16]) for i in range(0, len(values), 16))
        return f"let {name}: [Int32] = [\n  {lines},\n]\n"

    def hex_array(name, values):
        lines = ",\n  ".join(
            ", ".join(f"0x{v:04X}" for v in values[i : i + 16]) for i in range(0, len(values), 16))
        return f"let {name}: [UInt16] = [\n  {lines},\n]\n"

    (out_dir / "BackdropAssets.swift").write_text(
        "// Generated by ports/NDS/tools/gen_backdrops.py - do not edit.\n"
        "\n"
        "/// Per-sprite-ID downscaled-backdrop data: byte offset into `backdrops.bin`, pixel\n"
        "/// width/height, and offset/count into `backdropPaletteTable` - all -1/0 for a sprite\n"
        "/// ID with no backdrop art (everything except the five bkgN room backdrops).\n"
        f"{int_array('backdropOffsetTable', offsets)}"
        f"{int_array('backdropWidthTable', widths)}"
        f"{int_array('backdropHeightTable', heights)}"
        f"{int_array('backdropPaletteOffsetTable', palette_offsets)}"
        f"{int_array('backdropPaletteCountTable', palette_counts)}"
        "\n"
        "/// Every backdrop's own small palette, concatenated (each entry's own\n"
        "/// `backdropPaletteOffsetTable`/`backdropPaletteCountTable` slice back into this).\n"
        f"{hex_array('backdropPaletteTable', palette_blob)}"
    )
    print(
        f"backdrops.bin: {converted} backdrops downscaled to ~{round(536*SCALE)}x{round(420*SCALE)}, "
        f"{len(blob)} bytes ({len(blob) / 1024:.1f} KB)"
    )


if __name__ == "__main__":
    main()
