# Junkbot for PlayStation 1

A working PlayStation 1 build in [Embedded Swift](https://www.swift.org/documentation/embedded-swift/),
targeting `mipsel-none-none-elf` (MIPS I / R3000A — an exact match for the PS1's CPU) against
[PSn00bSDK](https://github.com/Lameguy64/PSn00bSDK), using a hand-patched LLVM/Swift toolchain
from `swift-embedded-ps1` (plain upstream/nightly Swift has no
`mipsel-none-none-elf` + `-mno-abicalls` support). Verified end-to-end in DuckStation: the shared
`GameEngine`/`RenderList`/`EntityFactory` from `Sources/JunkbotCore` — the same code every other
port runs — constructs, simulates, and renders a hand-built test level, with D-pad/Cross input
driving a virtual cursor for grab/drag/drop.

**Read [KNOWN_ISSUES.md](KNOWN_ISSUES.md) before touching the Swift/LLVM toolchain pieces of this
port.** Getting `Array`/`Dictionary`/`Set` and ordinary control flow working at all on this
target required finding and working around four distinct upstream Embedded Swift/LLVM codegen
bugs — the short version is in "Why this port needed extra work" below, but the full
GDB-verified root-cause writeup (recompiled block disassembly, exact instruction sequences,
isolation steps) is only in that file.

## v1 scope

A single hand-built test level (8 ground bricks, a bin, Junkbot standing) — this port doesn't yet
parse real level data or the campaign (`Generated/JunkbotLevelData.swift` is excluded from the
build; see `compile-swift.sh`'s `GENERATED_EXCLUDE`). No viewport scrolling (the test level fits
on one screen) and no audio yet.

| Input | Action |
| --- | --- |
| D-pad | Move the virtual cursor by one grid cell (nudge on press, software auto-repeat while held) |
| Cross | Grab / drag / drop at the cursor |
| Start | Restart the level |

Not yet implemented, in rough order of what a v2 would tackle first:

- **Real level data / the campaign.** Same mechanism other ports use (`GameEngine.loadLevelState`
  from a pre-parsed entity list) would work here too; just not wired up yet.
- **Audio.** PS-ADPCM (VAG) sound effects/music via the SPU — no code yet.
- **Viewport scrolling / a HUD.** Needed once real (larger) levels are loaded.
- **CI.** No GitHub Actions job builds this port yet (see the repo root's `.github/workflows`).

## Prerequisites

- The patched Embedded Swift + LLVM/clang/lld toolchain built per
  `swift-embedded-ps1`'s README (its README documents the 6 source patches
  this target needs — plain nightly Swift can't target `mipsel-none-none-elf` at all). Override
  `TOOLCHAIN` if it isn't at this port's default path (`compile-swift.sh`).
- PSn00bSDK headers + `.a` libs at `psn00bsdk/` (vendored from `swift-embedded-ps1`; see that
  repo's `Support/psn00bsdk` for how they were built).
- Python 3 (`tools/gen_assets.py`'s sprite-sheet conversion, `Support/elf2psexe.py`,
  `Support/fix_atomics.py`).
- [DuckStation](https://github.com/stenzek/duckstation) to run the resulting `.psexe` (no real
  hardware/BIOS testing has been done).

```sh
make all
```

produces `Junkbot.psexe`. `make clean` removes all generated/build output.

## Layout

- `Makefile` — see its own header comment for the full build/link pipeline.
- `compile-swift.sh` — the Swift compilation step in detail: `swift-frontend -emit-ir`, then
  `Support/fix_atomics.py` rewrites the emitted IR (strips atomic RMW instructions LLVM's Mips
  backend would lower to unavailable `ll`/`sc`), then `llc` lowers the fixed IR to a `mipsel`
  object. `CORE_EXCLUDE`/`GENERATED_EXCLUDE` mirror `ports/N64`'s: `Font.swift`/`LevelCatalog.swift`
  are Foundation-dependent (unneeded so far); `UndercoverLevelData.swift`/`LevelData.swift`/
  `JunkbotLevelData.swift` are the campaign data, excluded until level loading is wired up.
- `common/` — the bridging layer: `psx_umbrella.h`/`module.modulemap` expose PSn00bSDK + this
  port's own headers to Swift; `shim.c`/`shim.h` provide the render context (double-buffered
  `DISPENV`/`DRAWENV`, `FntSort` debug text), the world framebuffer, pad input
  (`ps1_init_pad`/`ps1_pad_held`, via the BIOS's classic continuous-poll `InitPAD`/`StartPAD`
  interface — PSn00bSDK's own `psxpad.h` has no handling functions yet), a bump allocator
  (`malloc`/`free`/`posix_memalign`, replacing PSn00bSDK's own to guarantee proper alignment —
  see the doc comment above `ps1_init_heap`), and a non-atomic `swift_once` override (see
  KNOWN_ISSUES.md Update 6).
- `source/` — the port itself: `main.swift` (pad setup, the test level, the input/tick/render main
  loop) and `Renderer.swift` (software rasterizer executing `GameEngine.buildRenderFrame`'s
  `RenderCommand` list into the RAM world framebuffer, plus the D-pad cursor crosshair).
- `Support/` — `boot.S`/`psexe.ld` (entry point + linker script, from `swift-embedded-ps1`),
  `elf2psexe.py` (ELF → `.psexe` header), `fix_atomics.py` (the atomic-RMW-stripping IR pass —
  see its own docstring and KNOWN_ISSUES.md Update 6 for why it exists).
- `tools/gen_assets.py` — sprite PNGs → 8bpp palette-index blob + Swift offset/palette tables
  (same pipeline as `ports/N64`/`ports/NDS`).
- `KNOWN_ISSUES.md` — the full debugging history for every upstream toolchain bug found on this
  target, in the order they were discovered. Load-bearing context for anyone touching this port's
  compile pipeline.

## Why this port needed extra work

Four distinct upstream Embedded Swift/LLVM codegen bugs, all ultimately caused by the same root
issue — **`ll`/`sc` (Load-Linked/Store-Conditional) don't exist on MIPS-I**, but LLVM's Mips
backend emits them anyway for atomic operations, regardless of `-mcpu=mips1` — surfacing through
three different Swift runtime mechanisms, plus one apparently-unrelated DuckStation recompiler
edge case:

1. `swift_retain`/`swift_release` compiled to real atomic RMW instructions → `ll`/`sc` → infinite
   retry loop (`sc` never reports success on this target). Fixed with `-assume-single-threaded`.
2. Dozens of *other* inlined ARC/copy-on-write uniqueness checks throughout the compiled module
   have the same problem, and aren't covered by that flag. Fixed by `Support/fix_atomics.py`,
   which mechanically rewrites every `atomicrmw`/`cmpxchg` in the emitted LLVM IR into a plain
   (non-atomic) load/op/store sequence before `llc` lowers it.
3. `swift_once` (gating `Dictionary`/`Set`'s lazily-initialized hash seed) uses the identical
   `ll`/`sc` compare-and-swap in a separate, `weak_odr` runtime symbol `-assume-single-threaded`
   doesn't touch. Fixed by overriding it with a plain non-atomic C implementation in `shim.c`
   (the same weak-symbol-shadowing trick this port already used for `malloc`/`free`).
4. A checked `%` (Swift inserts a divide-by-zero trap around integer modulo) in
   `RenderList.swift`'s `junkbotFrame()` triggers what looks like a DuckStation
   recompiler/interpreter bug around `div`/`teq`/`mfhi` sequences under cache-invalidation
   pressure — not a Swift or LLVM bug (real MIPS-I hardware handles this instruction sequence
   fine). Fixed with a manual subtract-based modulo at that one call site.

See KNOWN_ISSUES.md for the GDB-verified diagnosis of each (DuckStation ships a built-in
gdbserver; Homebrew's `gdb`, built with `--enable-targets=all`, includes `mips:3000` support even
though it was never packaged specifically for the PS1).

With all four fixed, this port uses `Sources/JunkbotCore`'s `GameEngine`/`RenderList`/
`EntityFactory` completely unmodified — no PS1-local `Array`/`Dictionary` reimplementation needed
(an earlier, now-abandoned approach; see git history if curious).
