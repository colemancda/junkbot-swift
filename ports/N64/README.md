# Junkbot for Nintendo 64

A working Nintendo 64 build in [Embedded Swift](https://www.swift.org/documentation/embedded-swift/),
targeting `mips-none-none-elf` (the VR4300's MIPS III core) against the open-source
[libdragon](https://github.com/DragonMinded/libdragon) SDK and its `n64.mk` build system. Verified
end-to-end in the [ares](https://ares-emu.net) emulator: analog-stick/D-pad-driven cursor
grab/drag/drop, sound effects/background music, a HUD overlay (level number, moves counter,
win/lose prompt), and level switching.

Build system and Embedded Swift/libdragon interop patterns are modeled on
[MillerTechnologyPeru/swift-embedded-nintendo-64](https://github.com/MillerTechnologyPeru/swift-embedded-nintendo-64)'s
`libdragon/` example.

## v1 scope

The whole game renders on the N64's single 320x240 screen through a scrollable viewport into the
world (levels are up to ~900x675 world px), with a HUD strip drawn directly over the world every
frame - unlike `ports/3DS`/`ports/NDS`, the N64 has no second screen or touchscreen, so there's no
separate console surface for it. The analog stick drives a virtual cursor for grab/drag/drop (an
on-screen crosshair, since - unlike a touchscreen - the player can't see where their finger is);
the D-pad also drives the cursor, but by exactly one stud per press, for placements the analog
stick can't land precisely on.

| Input | Action |
| --- | --- |
| Control stick | Move the cursor |
| D-pad | Move the cursor by one stud (precise nudge) |
| A | Grab / drop at the cursor |
| C buttons | Scroll the viewport |
| L / R | Previous / next level |
| START | Restart the current level |

Not yet implemented, in rough order of what a v2 would tackle first:

- **A title screen / level-select menu.** The ROM boots straight into level 1; there's no way to
  jump to an arbitrary level other than holding L/R through the whole campaign.
- **The Undercover Exclusive campaign.** Only the base `junkbotCampaignLevels` set is embedded
  (see `compile-swift.sh`'s `GENERATED_EXCLUDE`) - referencing the combined `embeddedLevels` array
  would make the *whole* Undercover Exclusive campaign's entity data reachable (and thus linked
  in), which the N64's 4MB whole-ELF RDRAM budget can't spare for a campaign this port doesn't
  play anyway.
- **Real audio streaming.** Every sound effect/music clip is pre-decoded to PCM and linked
  directly into the ROM (see "Audio and music" below) - simple, but bounded by the whole-ELF
  RDRAM budget alongside everything else. A DragonFS-backed streaming player would remove that
  ceiling entirely at real implementation cost.

## Prerequisites

Unlike `ports/3DS`/`ports/NDS` (devkitPro toolchains with a nightly Swift snapshot), this port
needs:

- **A custom Swift toolchain with a `mips-none-none-elf` Embedded stdlib slice.** No public Swift
  release or nightly ships one (MIPS isn't an officially-supported Embedded Swift target); this is
  a from-source build. This repo's CI downloads a packaged one from a GitHub Release asset in this
  repo (see `.github/workflows/swift.yml`'s `n64` job) - grab the same `swift-embedded-mac.tar.gz`
  and point `SWIFTC` at its `bin/swift-frontend` (not `swiftc`/`swift-driver` - see
  `compile-swift.sh`'s header comment for why the driver isn't portable enough to invoke here).
- **`llc`** with the MIPS backend (mainline LLVM ships this by default - Homebrew's `llvm` works).
  Set `LLC=/path/to/llc`.
- **Docker**, for libdragon's `mips64-elf` GCC toolchain and library (this port's `Dockerfile`
  builds from `ghcr.io/dragonminded/libdragon`). CI splits this across two jobs (`n64` compiles
  Swift on a macOS runner, `n64-rom` links the ROM on a Linux runner) since GitHub-hosted macOS
  runners can't run Docker (no nested virtualization) - see those jobs' comments.
- **macOS**, for `build.sh`'s asset-conversion scripts (`afconvert`/`sips`), matching every other
  native port's asset pipeline.

```sh
SWIFTC=/path/to/swift-embedded-mac/bin/swift-frontend LLC=/path/to/llc ./build.sh
```

produces `Junkbot.z64`. `make clean` (from inside a container, or with `N64_INST` set locally)
removes generated build output.

## Layout

- `build.sh` - host-side asset generation (`tools/gen_*.py`) + `compile-swift.sh`, then builds the
  libdragon Docker image and runs `make` inside it to link the ROM. See its own comments for the
  full pipeline.
- `compile-swift.sh` - the Embedded Swift MIPS compile: `swift-frontend -emit-ir` -> `llc` (with
  `-mattr=+mips3,+noabicalls,+gp64,+fpxx,+nooddspreg,-mips4_32,-mips4_32r2`, disabling MIPS IV
  `movn`/`movz` the VR4300 doesn't have) -> an ELF ABI retag from O32 to O64 (libdragon links
  `-mabi=o64`; LLVM can only emit o32, but the object is already `+gp64`-compatible, so only the
  `e_flags` word needs patching - see the script's comments for the full explanation).
- `Makefile`/`Dockerfile` - libdragon's `n64.mk`, linking the Swift object + `common/shim.c` +
  `objcopy`-embedded asset blobs (bin2s isn't available in this toolchain, so raw binaries are
  embedded via `mips64-elf-objcopy -I binary` instead - see `common/assets.h`'s comment on why
  sizes are computed as a start/end pointer difference rather than bin2s's `<name>_size` word).
- `common/` - the CN64 bridging module: `module.modulemap`/`n64_umbrella.h` expose this port's own
  shim (not libdragon's headers directly - see the umbrella header's comment) to Swift as
  `import CN64`. Every bridge function is `<=4` register arguments, no floats, no stack arguments
  (libdragon is o64/8-byte stack slots; the Swift object is o32/4-byte slots), and per-call, not
  per-sprite/per-sample - `n64_display_attach`/`n64_audio_begin`/`n64_buttons_held` hand Swift a
  raw pointer once per frame, and all the actual pixel/sample work happens in pure Swift on that
  pointer.
- `source/` - the port itself:
  - `main.swift` - controller/audio/video setup, level loading, the input/tick/render main loop.
  - `Renderer.swift` - the software rasterizer: executes the engine's `RenderCommand` list into a
    double-buffered native 16bpp 5551 framebuffer, culled to the current scrolled viewport (plus a
    margin) before the engine's entity-sort pass, since a busy campaign level can have 100+
    entities scattered across a world far larger than one 320x240 screen (see
    `GameEngine.buildRenderFrame`'s `visibleBounds` parameter). Sprites are 8bpp palette-index
    (`tools/gen_assets.py`, the same DS-budget format as `ports/NDS`, not `ports/3DS`'s
    uncompressed 16bpp - the N64 loads its *entire* ELF into just 4MB of RDRAM at boot, with no
    separate large-flash tier to lean on the way 3DS/NDS have); background-sheet images are
    skipped entirely in favor of clearing to the backdrop's average color, for the same reason.
  - `TextRenderer.swift` / `Audio.swift` - see their own doc comments.
- `tools/` - host-side (native, non-Embedded) asset converters: `gen_assets.py` (sprite PNGs ->
  8bpp palette-index blob), `gen_audio.py`/`gen_music.py` (sound effects/music -> PCM16, this
  port's own software mixer resamples to the output rate - no maxmod/NDSP-equivalent hardware
  mixer here), `gen_font.py` (the bitmap font atlas -> an ASCII-byte-indexed glyph table for the
  HUD, since even iterating a `Character`/`String` needs the Embedded stdlib's grapheme-breaking
  data tables this ROM's budget can't spare). Levels are NOT generated here: they come from
  `Sources/JunkbotCore/Generated/JunkbotLevelData.swift`, shared with every port and produced by
  the repo root's `make codegen`.

## Controller input caveats (libdragon/ares specifics)

Two hardware/toolchain quirks this port works around, both discovered empirically rather than
from documentation - see `source/main.swift`'s `BTN_*` constants and its `A` button handling for
the full write-ups:

- **`joypad_buttons_t`'s bitfield allocation is reversed from declaration order** on this
  big-endian MIPS target: GCC packs the first-declared field into the *most* significant bit, not
  the least. DWARF debug info initially (and misleadingly) suggested declaration order matched bit
  position directly - that's a known GCC MIPS/big-endian `data_bit_offset` quirk, not the real
  in-register layout.
- **`held` lags `pressed` by one frame**: libdragon's `held` snapshot reads 0 for a button on the
  exact same frame `pressed` reports it, so gating a drag's release on `held` alone released every
  grab one frame after it started, before any cursor movement could register. Fixed by treating a
  button as "down" if either `pressed` or `held` says so.

## Performance

Level 1 (~120 entities, mostly off-screen floor segments) was slow enough to notice: `GameEngine`'s
`sortOrderForRendering` (painter's-algorithm draw ordering) is a bubble-sort variant that scales
worse than linearly with entity count, and ran every frame at 60Hz over *every* entity regardless
of visibility. Two fixes, both in shared `Sources/JunkbotCore` code (so every port benefits):
`canRelease()`/`allConnectedToFixed()` (recomputed every frame while dragging) now use `Set`-backed
membership checks instead of `Array.contains`; and `buildRenderFrame` takes an optional
`visibleBounds` rect to cull off-screen entities before the sort, which this port (along with
`ports/NDS`/`ports/3DS`) passes as the current scrolled viewport plus a margin. See
`Tests/JunkbotCoreTests/DragPerformanceTests.swift` and the `visibleBounds` tests in
`Tests/JunkbotCoreTests/RenderListTests.swift` for the measured before/after numbers.
