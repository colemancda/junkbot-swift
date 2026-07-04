# Junkbot for Nintendo DS

A working Nintendo DS build in [Embedded Swift](https://www.swift.org/documentation/embedded-swift/),
targeting `armv5te-none-none-eabi` (an exact match for the DS's ARM946E-S) against
[devkitPro](https://devkitpro.org)'s modern calico-based libnds. Verified end-to-end in melonDS:
touch-drag gameplay on the bottom screen, sound effects and background music, and a bitmap-font
info panel on the top screen.

Build system and Embedded Swift/libnds interop patterns are modeled on
[MillerTechnologyPeru/swift-embedded-nds](https://github.com/MillerTechnologyPeru/swift-embedded-nds).

## v1 scope

The whole game renders on the bottom (touch) screen through a scrollable viewport into the world
(the DS is 256x192; levels are up to ~900x675 world px). There's no virtual cursor - the stylus
position directly drives the engine's mouse-down/move/up, matching a touchscreen rather than a
mouse. The top screen is a static info panel (level title/hint, moves counter, win/lose prompt),
not a second view into the world.

| Input | Action |
| --- | --- |
| D-pad | Scroll the viewport |
| Stylus | Grab / drag / drop bricks |
| L / R | Previous / next level |
| START | Restart the current level |
| A (or a stylus tap) | Advance the win/lose prompt |

Not yet implemented, in rough order of what a v2 would tackle first:

- **A title screen / level-select menu.** The ROM boots straight into level 1; there's no way to
  jump to an arbitrary level other than holding L/R through the whole campaign.
- **Real audio streaming.** Every sound effect and music clip is pre-decoded to 8-bit PCM and
  linked directly into the ARM9 binary (see "Audio and music" below) - simple, but bounded by the
  ARM9 image's ~2.48MB budget alongside everything else. A NitroFS-backed streaming player would
  remove that ceiling entirely (more/longer music, higher-fidelity sound) at real implementation
  cost (maxmod or hand-rolled double-buffered streaming - see that section for why this v1 didn't
  attempt it).
- **The Undercover Exclusive campaign.** Only the base `levels/` set is embedded; extending
  `tools/LevelDump`/the sprite/level pipelines to include `levels/Undercover Exclusive/` is
  mechanical but untested.

## Prerequisites

- [devkitPro](https://devkitpro.org) with `devkitARM`, `libnds`, `calico`, `ndstool`, and `bin2s`
  (the `nds-dev` + `general-tools` package groups). `export DEVKITPRO=/opt/devkitpro
  DEVKITARM=$DEVKITPRO/devkitARM`.
- A Swift toolchain whose Embedded stdlib ships an `armv5te-none-none-eabi` slice. As of this
  writing, release toolchains (6.3.2) only ship `armv4t`; a recent `main` development snapshot has
  the `armv5te` slice this build targets. Point `make` at it with `SWIFTC=/path/to/swiftc`.
- macOS. Sound effects, music, and the bitmap font are all pre-converted from the repo's source
  assets at build time (see below), and those conversion scripts shell out to macOS's `afconvert`
  (Ogg Vorbis decoding) and `sips` (the font atlas's 4-bit-palette PNG). Everything else
  (devkitARM, the Swift compiler itself) is cross-platform, so lifting this restriction would just
  mean swapping those two tools for a portable decoder.

```sh
make SWIFTC=/path/to/swiftc
```

produces `Junkbot.nds`. `make clean` removes all generated/build output.

## Layout

- `Makefile` - see its own header comment for the full build-pipeline explanation. In short: all
  of `../../Sources/JunkbotCore` (minus a couple of files - see below) plus `source/*.swift` are
  compiled as one whole-module Embedded Swift object, linked against calico's `libnds9`/
  `libcalico_ds9` via `-specs=ds9.specs`, and packaged with `ndstool` using calico's prebuilt ARM7.
- `common/` - the CNDS bridging module: `module.modulemap`/`nds_umbrella.h` expose libnds + this
  port's own headers to Swift as `import CNDS`; `shim.c`/`shim.h` provide fixed-arity `iprintf`
  wrappers (Embedded Swift can't call C varargs) and runtime support devkitARM's libc doesn't
  supply for this target (`posix_memalign`, `__atomic_*` outline helpers, `arc4random_buf`);
  `assets.h` declares the bin2s-embedded asset blobs and stable-pointer accessors for Swift (a C
  array imports into Swift as a copied tuple, not a pointer to the real linked symbol).
- `source/` - the port itself:
  - `main.swift` - video/audio setup, level loading, the input/tick/render main loop.
  - `Renderer.swift` - the bottom screen's software rasterizer: executes the engine's
    `RenderCommand` list into a double-buffered 16bpp bitmap background, camera-scrolled by the
    D-pad. Sprites are 8bpp palette-index (the whole sprite set is under 255 unique colors,
    lossless); background-sheet images are skipped entirely (see "Why sprites but not
    backgrounds" below) in favor of clearing to the backdrop's average color.
  - `TextRenderer.swift` / `Audio.swift` - see their own sections below.
- `tools/` - host-side (native, non-Embedded) asset converters, each documented in its own
  docstring:
  - `gen_assets.py` - sprite PNGs -> 8bpp palette-index blob + Swift offset/palette tables.
  - `gen_audio.py` / `gen_music.py` - sound effects / background music -> 8-bit PCM.
  - `gen_font.py` - the bitmap font atlas -> a 1bpp glyph bitmap + ASCII-byte glyph table.
  - `LevelDump` (a small host Swift package) - every campaign level, parsed through
    `JunkbotCore`'s real level-text parser natively and frozen as entity-builder Swift.

## Why sprites but not backgrounds

Both live in `images/` at similar apparent size, but the ARM9 binary the DS boots directly into
RAM is capped at roughly 2.48MB (`lma9` in calico's `ds9.ld`) for everything: engine code, sprite
pixels, every level, every sound clip. The sprite sheet fits (8bpp, ~750KB); the *background*
sheet's full-size images alone would roughly double that. Rather than a partial/cropped
compromise, backgrounds are dropped entirely and the world clears to each backdrop's average
color instead (`tools/gen_assets.py` computes it at build time) - a flat tint rather than the
original artwork, but it keeps every level's silhouette (bricks, hazards, Junkbot) legible, which
is what actually matters for play.

## Why levels are pre-parsed, not parsed on-device

`Sources/JunkbotCore`'s level-text parser (`LevelParse.swift`, `LevelEntityBridge.swift`, etc.)
uses ordinary Swift `String` operations (`.lowercased()`, `Character` iteration) that need the
Embedded stdlib's Unicode grapheme-breaking/case-mapping data tables - real weight (~800KB) this
ROM's budget can't spare, and already the reason those files are excluded from the embedded-WASM
build too (`#if !hasFeature(Embedded)`). Instead, `tools/LevelDump` runs the *real* parser
natively on the host at build time and freezes every campaign level's resulting entity list as
plain entity-builder Swift (`build/LevelAssets.swift`) - the DS binary never sees level text at
all, just `GameEngine.loadLevelState(entities:levelBounds:nextID:)` calls.

`Sources/JunkbotCore/Font.swift` and `Sources/JunkbotCore/LevelCatalog.swift` are excluded from
this port's build for the same underlying reason (see the Makefile's `CORE_EXCLUDE`) - unlike the
WASM build, this port's simpler devkitARM link doesn't dead-strip their unused `.uppercased()`/
`.lowercased()` calls on its own, so left in they pulled in the same ~800KB for code nothing here
actually calls.

## Audio and music

No maxmod, no soundbank, no NitroFS streaming - every clip is pre-decoded at build time
(`tools/gen_audio.py` for sound effects, `tools/gen_music.py` for music) to signed 8-bit PCM and
linked straight into the ARM9 binary, played with libnds/calico's `soundPlaySample`
(`source/Audio.swift`). That's simple and needs no per-frame CPU attention once a sound starts,
at the cost of being bounded by the same ~2.48MB ROM budget as everything else:

- Sound effects (mirroring `ports/SDL2`'s `SoundBoard` table 1:1) are kept at their native 16kHz.
- Music is simplified from `ports/SDL2`'s `MusicPlayer` (5 named "level" groups, one picked at
  random per level, each cycling several short loopable phrases plus a fade-out sting): this port
  picks one random group and just one random track from it, looped forever in hardware
  (`soundPlaySample(...,loop:true)`), with no shuffling between a group's tracks and no fade-out
  sting. Tracks are downsampled to 8kHz - at the source 16kHz the 5 groups alone were ~716KB,
  which didn't fit; halving the rate roughly halves the size for an acceptable quality loss on
  music this short and already lo-fi.

## Top screen (bitmap font)

The top screen is a second MODE_5 bitmap background (not the stock libnds text console), filled
grey and redrawn with the game's own proportional bitmap font (`font/font.png`, the same asset
every other native port draws) whenever the level, moves counter, or win/lose state changes -
`source/TextRenderer.swift`. Like the level-text parser, this deliberately doesn't call
`Sources/JunkbotCore/Font.swift`'s own `Character`/`String`-based API - even just iterating a
`String` needs the same Unicode data tables the parser does. `tools/gen_font.py` instead converts
the font atlas into a table indexed directly by ASCII byte value (case-folded, since the atlas
only has uppercase glyphs), which every string this port actually draws satisfies: level titles/
hints are baked into `build/LevelAssets.swift` as `StaticString` by `LevelDump`, and every other
on-screen string is a `StaticString` literal this port's own source writes.
