# Upstream bugs on `mipsel-none-none-elf` — RESOLVED (see Update 6/7 for the actual root causes)

**Read Update 6 and Update 7 first.** Updates 1-5 below are preserved as the literal
debugging history (useful for anyone hitting similar symptoms on an experimental pre-MIPS32
Embedded Swift target), but they're all downstream *symptoms* of the same handful of root
causes, not independent bugs: (1) `swift_retain`/`swift_release` compiling to `ll`/`sc`
(Load-Linked/Store-Conditional) instructions that don't exist on MIPS-I, fixed with
`-assume-single-threaded`; (2) the same `ll`/`sc` pattern inlined into dozens of *other*
ARC/COW-uniqueness sites `-assume-single-threaded` doesn't reach, fixed by mechanically
rewriting the emitted LLVM IR (`Support/fix_atomics.py`); (3) `swift_once` (gating `Dictionary`/
`Set`'s lazy hash-seed init) using the identical `ll`/`sc` CAS, fixed by overriding the weak
`swift_once` symbol with a plain non-atomic C implementation; and (4) an unrelated DuckStation
recompiler edge case around checked-`%`'s `div`/`teq`/`mfhi` sequence, fixed with a manual
modulo at the one call site that hit it. With all four fixes in place, the full shared
`GameEngine`/`RenderList`/`EntityFactory` from `Sources/JunkbotCore` works directly on this
target — no PS1-local `Array`/`Dictionary` reimplementation needed.

## Summary

On the patched Embedded Swift toolchain used by `swift-embedded-ps1` (target
`mipsel-none-none-elf`, MIPS I / R3000A, `-mno-abicalls -fno-pic -relocation-model=static`),
`Array`/`ContiguousArray`'s internal storage-class allocation calls `posix_memalign`
with a **corrupted `size` argument**. The value observed is always "a plausible small
byte count with garbage in the upper 16 bits" — e.g. the real size looks like it should be
`0x0000006C` (108) but arrives as `0x5104006C`, or `0x00000014` (20) arrives as `0x48100014`.

This reproduces with a single `.append()` call on a freshly-created empty `Array<Int32>`
or `ContiguousArray<Int32>` — the very first heap growth. It does **not** reproduce with
`UnsafeMutableRawPointer.allocate(byteCount:alignment:)`, which receives correct arguments
and succeeds every time. This isolates the bug to the Array storage class's internal size
computation (likely `_ContiguousArrayStorage`'s tail-allocation byte-count math), not to
anything downstream (allocator, alignment, calling convention in general).

## Environment

- Toolchain: `/Volumes/Crucial-2TB/Developer/build/Ninja-ReleaseAssert` (local build per
  `swift-embedded-ps1`'s README patch set)
- `swiftc --version`: `Swift version 6.5-dev (LLVM 9597da2255fb6d2, Swift 0cc6e978b39043d)`,
  `Target: arm64-apple-macosx26.0`, `Build config: +assertions`
- Target triple: `mipsel-none-none-elf`
- Repro built via `ports/PS1` in `junkbot-swift` (a new, in-progress port scaffolded on top
  of `swift-embedded-ps1`'s toolchain/boot/linker-script), run in DuckStation 0.1-11515.

### Compile flags (from `ports/PS1/compile-swift.sh`, copied from
`swift-embedded-ps1/Makefile`'s `SWIFTFLAGS_COMMON`)

```
-target mipsel-none-none-elf
-enable-experimental-feature Embedded
-wmo -Osize
-Xcc -march=mips1
-Xcc -mabi=o32
-Xcc -mno-abicalls
-Xcc -fno-pic
-Xcc -fno-PIC
-Xcc -msoft-float
-Xcc -fno-stack-protector
-Xcc -I<psn00bsdk include dir>
-Xcc -w
-Xllvm -mattr=+noabicalls
-Xllvm -relocation-model=static
```

Compiled directly to an object with `swiftc ... -c` (this toolchain's patches let it emit
MIPS I object code directly — no separate `-emit-ir` + `llc` step needed).

## Minimal repro

```swift
// swift_main is called from boot.S -> a small C shim that does ResetGraph/FntLoad
// (PSn00bSDK init) before jumping in. Heap is a straightforward bump allocator
// (ruled out as the cause — see "What's been ruled out" below).
@_cdecl("swift_main")
public func swiftMain() {
  ps1_init_heap()
  ps1_init_display()

  // This line's internal posix_memalign call receives a corrupted `size`.
  var arr: [Int32] = []
  arr.append(1)   // <-- hangs (see "Symptom" below)

  while true { }
}
```

Also reproduces with:
```swift
var arr = ContiguousArray<Int32>()
arr.append(1)
```
and with:
```swift
let arr = [Int32](repeating: 0, count: 4)   // fixed-size initializer, not just growth
```

Does **NOT** reproduce with:
```swift
let p = UnsafeMutableRawPointer.allocate(byteCount: 4, alignment: 4)  // works every time
```

## Symptom

With a naive `posix_memalign` (see "What's been ruled out"), the corrupted size causes
`malloc`/`InitHeap`-backed allocators to return NULL or a bad pointer, which Swift's runtime
turns into a trap — but on this target there is **no installed exception handler**, so the
CPU silently spins forever at the reset/exception vector. From the outside (DuckStation) this
looks like a plain hang: the emulator's own UI keeps running at 60 FPS, but the "Game" FPS
counter drops to 0 and the framebuffer freezes on whatever was last presented. There is no
crash log, no exception message — nothing indicates a fault occurred unless you already
suspect this exact failure mode.

## How the `size` corruption was isolated (debug instrumentation)

To rule out the allocator, `posix_memalign` was temporarily instrumented to draw the raw
hex value of `alignment`, `size`, and the allocator's own bookkeeping directly to the PS1
screen via the PSn00bSDK debug font, immediately (flipping both video buffers before doing
anything else, so the values are visible even if the process hangs one instruction later):

```c
int posix_memalign(void **memptr, size_t alignment, size_t size) {
  // ... draw hex(alignment), hex(size), hex(heap_next), hex(heap_top) to screen,
  // flipping after each line onto BOTH double-buffers so it survives a hang ...
  void *p = bump_alloc(size, alignment < sizeof(void*) ? sizeof(void*) : alignment);
  // ... draw hex(p) ...
  if (!p) return 12;
  *memptr = p;
  // ... draw "stored ok" ...
  return 0;
}
```

Two separate runs (`Array<Int32>` append, then `Array(repeating:count:)`) captured:

| Call | `align` | `size` (raw) | Plausible real size | Result |
|---|---|---|---|---|
| `[Int32]().append(1)` | `0x00000004` | `0x5104006C` | `0x0000006C` (108 bytes) | allocator returns NULL (heap logic sees a ~1.36GB request) → hang |
| `[Int32](repeating:0,count:4)` | `0x00000004` | `0x00000020` | (this one arrived correct) | succeeded, "STORED OK" |
| `ContiguousArray<Int32>().append(1)` | `0x00000004` | `0x48100014` | `0x00000014` (20 bytes) | allocator returns NULL → hang |

Note the pattern in the two failing cases: the **low 16 bits are a small, entirely
plausible byte count** (108 and 20 — both consistent with a small header + a handful of
`Int32` elements), while the **high 16 bits contain nonzero garbage** (`0x5104` and
`0x4810`). This is the classic signature of a 32-bit-constant-materialization bug on MIPS:
a value is built as `lui $reg, <garbage-or-uninitialized-hi>` followed by `ori $reg, $reg,
<correct-lo>` (or an add of a 16-bit-only computed delta into a register that was never
correctly zero-extended/cleared beforehand). Whatever intermediate 32-bit arithmetic
`Array`'s tail-allocation size computation does (roughly:
`roundUpToAlignment(headerSize) + capacity * MemoryLayout<Element>.stride`, likely computed
via `Builtin.allocWithTailElems_1` and inlined UMulOver/shift-add sequences at `-Osize`)
appears to occasionally miscompile on this backend, leaving stale/garbage bits in the upper
half of the word.

The third row above (`Array(repeating:count:)`) succeeded with a correct `size` in that
particular run — so this is not 100% deterministic per call site; it may depend on register
allocation/reuse at the specific call site, consistent with a "stale register not cleared"
theory rather than a fully wrong formula.

## What's been ruled out

1. **Not our `posix_memalign` shim ignoring `alignment`.** The first hypothesis was that a
   naive `posix_memalign(void**, size_t, size_t) { *memptr = malloc(size); return 0; }`
   (ignoring the requested alignment) produced a misaligned pointer, and the R3000A's
   hard fault on misaligned word access was the real crash. This was fixed with a proper
   bump allocator that honors the requested alignment — the hang persisted identically,
   ruling this out.
2. **Not heap size/bounds.** The bump allocator's `s_heap_next`/`s_heap_top` were confirmed
   correct and with ample headroom (`next: 0x80139CC8`, `top: 0x801E0000`, hundreds of KB
   free) at the moment of the bad call.
3. **Not a C/Swift calling-convention mismatch in general.** `alignment` (the 2nd argument)
   consistently arrives correct in every run. Only `size` (the 3rd argument) is
   corrupted, and only when it originates from `Array`/`ContiguousArray`'s internal
   allocation, never from a directly-written `UnsafeMutableRawPointer.allocate` call with a
   literal byte count. If this were a general O32 argument-passing bug, `alignment` would
   likely also be affected, and `UnsafeMutableRawPointer.allocate` (which also ends up
   calling `posix_memalign` with a compile-time-ish literal) would fail too.
4. **Not the linker's known-benign warnings.** Every build (including ones that work fine,
   like the plain `UnsafeMutableRawPointer.allocate` repro) emits
   `ld.lld: warning: can't find matching R_MIPS_LO16 relocation for R_MIPS_GOT16` (from
   PSn00bSDK's old mipsel-gcc-built `.a` archives) and
   `ld.lld: warning: build/swiftlib.o: linking abicalls code with non-abicalls code build/boot.o`.
   These are present identically in both passing and failing runs, so they're not
   correlated with this bug.

## Update 3: the `-emit-ir`+`llc` "fix" below turned out to be context-sensitive, not reliable

**Read this before trusting the "Update" section directly below.** A standalone, minimal
reproduction of this bug was built in `~/Developer/swift-embedded-ps1` (`make arraytests` /
`make arraytests-llc`, see that repo's own `KNOWN_ISSUES.md`) to isolate the exact
`.append()`-growth shape described below (`var arr: [Int32] = []; arr.append(1); arr.append(2)`)
with nothing else around it. In that cleaner repro, **both** `swiftc -c` and `-emit-ir`+`llc`
hang at the same point — the `-emit-ir`+`llc` route did NOT avoid the corruption there, unlike
in this repo's own (more complex, real-game-code) repro context where it did. So the
`-emit-ir`+`llc` pipeline is not a dependable workaround in general; it happened to sidestep
the corruption in this specific repo's repro context but not in a simpler one built later. This
is now the strongest evidence that the bug is sensitive to register allocation/live-range reuse
around the growth call site (which differs between repro contexts), not a deterministic
per-pipeline behavior. `ports/PS1`'s `compile-swift.sh` still uses `-emit-ir`+`llc` (kept for
consistency with `ports/N64`'s existing pattern and because it's not actively harmful), but
don't treat it as "the fix" for this bug — see `~/Developer/swift-embedded-ps1/KNOWN_ISSUES.md`
for the full, corrected picture and the reusable minimal repro.

## Update: `swiftc -c` (integrated codegen) vs. `-emit-ir` + `llc` (like `ports/N64`)

`ports/N64` doesn't hit this bug despite being just as `Array`-heavy, and it uses a
different compilation pipeline: `swift-frontend -frontend -emit-ir` followed by a
**separate, standalone `llc`** invocation, rather than plain `swiftc ... -c` (see
`ports/N64/compile-swift.sh`'s doc comment — that target's toolchain has no native
codegen for VR4300 quirks, so it has always gone through this path; `ports/PS1` only uses
`swiftc -c` directly because the patched toolchain's integrated codegen *can* emit MIPS I
objects directly, so nothing forced the split). This suggested a diagnostic: does routing
`ports/PS1`'s compile through the *same* two-step `swift-frontend -emit-ir` + `llc` shape,
using the exact same patched toolchain (so still the same LLVM MIPS backend under the
hood — this is not a different backend, just a different invocation path into it), change
the outcome? See `ports/PS1/compile-swift-llc.sh` (new, diagnostic-only, not part of the
normal build) for the exact commands:

```
swift-frontend -frontend -target mipsel-none-none-elf -enable-experimental-feature Embedded \
  -wmo -Osize <same -Xcc flags as compile-swift.sh> -emit-ir -o build/swiftlib.ll <sources>

llc -mtriple=mipsel-none-none-elf -mcpu=mips1 -mattr=+noabicalls,+soft-float \
  -relocation-model=static -filetype=obj -o build/swiftlib.o build/swiftlib.ll
```

**Result: this route DOES fix the corrupted-`size` symptom above.** Re-running the exact
`[Int32]().append(1)` repro through this pipeline gave `size = 0x00000014` (20, correct,
no garbage upper bits) on the first allocation, and a second growth call
(`arr.append()` a second time) also got a clean `size = 0x00000018` (24, correct) — both
confirmed via the same screen-based instrumentation. This is strong evidence the original
bug is specific to whatever `swiftc`'s integrated MIPS codegen invocation does differently
from a plain `-emit-ir` + `llc` pipeline through the same LLVM libraries (different default
pass ordering/options at the driver level, most likely — not a different backend, since
it's the same toolchain build).

**However, this is not a full fix — a second, distinct hang exists downstream.** With the
corrupted-size symptom gone, a *new* deterministic hang appeared on the array's first growth
reallocation (going from capacity 1 to capacity 2, i.e. the second `.append()` call on an
array that started empty):

```swift
var arr: [Int32] = []
arr.append(0)   // succeeds
arr.append(1)   // hangs -- this specific call never returns
```

Per-iteration Swift-level checkpoints (`drawText` + `ps1_flip` immediately before/after each
`append`, avoiding any C-level instrumentation that could itself confound the result) show
`"ITER 0 DONE"` and `"ITER 1 START"` both print, but `"ITER 1 DONE"` never appears — so the
hang is *inside* `arr.append(1)` specifically. Crucially, C-level tracing in the same run
showed this second call's own `posix_memalign` **already returned successfully** with a
correct size and a valid pointer before the hang — so this second bug is not the size
corruption recurring. It's somewhere further along the growth path: most likely the
compiler-generated loop/`memmove`-equivalent that copies the old (capacity-1) buffer's
element(s) into the new (capacity-2) buffer, or retain/release handling on the old buffer
being deallocated. This has **not yet been isolated further** — whether it's present under
`swiftc -c` too is unknown (under that path, the *first* `posix_memalign` call already fails
with a corrupted size, so a growth-copy bug on the *second* call is never reached/observed).

## Suggested next steps for someone fixing this upstream

- **For the `size`-corruption bug (fixed by the `llc` route):** since it's isolated to
  `swiftc`'s integrated codegen invocation vs. `swift-frontend -emit-ir` + `llc` on the
  *same* LLVM libraries, diff what options/pass pipeline each path actually constructs for
  this target. Compare `swiftc -v -c ...` (integrated) against
  `swift-frontend -frontend -emit-ir` + `llc` (in `compile-swift-llc.sh`) with LLVM pass
  logging (`-mllvm -print-after-all` on both) around the `Builtin.allocWithTailElems_1`
  lowering — the same repro (`[Int32]().append(1)`) is small enough to diff completely.
  Also worth compiling the same repro for `armv6-none-none-eabi` (`ports/3DS`) or
  `mips-none-none-elf` (`ports/N64`) and diffing the array-growth IR/assembly against this
  target's, since neither of those ports' `Array`-heavy `JunkbotCore` hits this.
- **For the growth-copy hang (not yet fixed by anything tried so far):** compile the
  2-append repro (`arr.append(0); arr.append(1)`) via `compile-swift-llc.sh`, add
  `-mllvm -print-after-all` to the `llc` invocation, and inspect what MIPS instructions are
  selected for the buffer-copy/move step of `Array`'s growth path (the code that runs after
  the new buffer is allocated and before the old one is released) — this is the next
  concrete thing to isolate; it hasn't been narrowed past "somewhere inside the second
  `.append()` call, after its own allocation already succeeded."
- Try dropping to `-Onone` (instead of `-Osize`) for both bugs to see if either is
  optimization-dependent (consistent with "stale register reused across an optimized live
  range" for the first bug; unknown for the second).

## Impact

This blocks using `Array`/`ContiguousArray` at all on this target, which blocks nearly all
of `Sources/JunkbotCore` (the shared game engine `junkbot-swift`'s other ports — WASM,
Darwin, Android, NDS, 3DS, N64 — all build on): `GameEngine.entities: [Entity]` and most of
`RenderList`/`Simulation`/`Collision` are `Array`-based. The `-emit-ir`+`llc` route fixes
the first bug (corrupted allocation size) but not the second (growth-copy hang on the very
next `.append()`), so as of this writing neither compilation path supports real `Array`
usage end-to-end. Until both are fixed upstream (or a workaround using only fixed-size
buffers / `UnsafeMutableRawPointer`-backed manual collections is built for every `Array` use
in the hot path — a much larger, invasive change), `ports/PS1` cannot run real game logic
beyond what's been verified so far: booting, PSn00bSDK GPU/font rendering, and heap
allocation via `UnsafeMutableRawPointer`.

## Update 2: a mitigation attempt (`reserveCapacity` everywhere) uncovered a third, more basic failure

Given the growth-copy hang above only triggers when an array grows *past its current
capacity*, the obvious mitigation was to make `Sources/JunkbotCore` (shared by every port)
pre-`reserveCapacity` every array that starts empty and grows via `.append()` during
simulation/input — mirroring what `Generated/JunkbotLevelData.swift`'s codegen already does
for `entities` (`entities.reserveCapacity(120)` before any append, sized exactly per level).
This is a legitimate perf win regardless of this bug (fewer reallocations on every port), so it
was applied broadly:

- `GameEngine.init()`: `wind`/`laserBeams`/`teleportEffects`/`draggingIndices`/`hoveredIndices`
  (small constants), plus `entitiesByTopY`/`entitiesByBottomY` (the *dictionaries* themselves,
  not just their bucket arrays — Dictionary's backing storage grows the same way Array's does).
- `RenderCommand.swift`'s `RenderFrame.init()`: `commands.reserveCapacity(256)`.
- `Collision.swift`'s `rectangleCollisionAll`/`connectsToFixed`, `Input.swift`'s
  `possibleGrabsAt`/`findAttachedGroup`: these are fresh *local* arrays rebuilt from empty on
  every call (can't rely on a one-time warm-up like a class's persistent arrays), so each got
  its own `reserveCapacity` at declaration.
- `AccelerationStructures.swift`'s `groupIndicesByY` and `Collision.swift`'s `entityMoved`:
  both had a `dict[key, default: []].append(...)`-shaped pattern (or the equivalent
  `dict[key] = [value]` for a brand-new key) — an array literal's capacity exactly matches its
  element count, so a *second* entity sharing that dictionary key (e.g. two bricks resting on
  the same floor y-coordinate — an extremely common case) would immediately need to grow past
  it. Rewrote both to explicitly `reserveCapacity` a fresh bucket before appending.

All of this is committed (it's a real, unconditional improvement for every port, confirmed via
`swift test --filter JunkbotCoreTests`, 48/48 still passing) but **it did not fix ports/PS1
end-to-end.** Bisecting a hand-built 10-entity test level (via the same "checkpoint" technique
as above — a global `public var debugCheckpoint: ((Int32) -> Void)?` in GameEngine.swift,
temporarily wired to draw+flip from `ports/PS1/source/main.swift`) traced the hang to
`GameEngine.resetLevel()`, specifically to one of its `*.removeAll(keepingCapacity: true)`
calls (`teleportEffects.removeAll`, in context — but see below, it's not specific to that array
or its element type).

**Isolated minimal repro:**

```swift
var a: [Int32] = []
a.reserveCapacity(8)
// ... draws/flips here — this point is reached fine ...
a.removeAll(keepingCapacity: true)
// ... never reached ...
```

This hangs identically whether `a` is `[Int32]` or `[TeleportEffect]` (ruling out
element-type-specific codegen), on an array that is **empty** and **already has capacity** —
there is no reallocation, no element copy, no COW divergence (nothing else holds a reference to
the buffer). `removeAll(keepingCapacity:)` on this input should reduce to approximately
"check `isKnownUniquelyReferenced` (true, no copy needed), set count to 0, optionally run
element deinitializers (trivial for `Int32`)". That this hangs too means the bug is not
isolated to the two array-growth code paths documented above — something more fundamental is
wrong with `Array`'s (and likely `Dictionary`'s, since its storage uses the same tail-allocated
buffer-class shape) method codegen on this `-emit-ir` + `llc` `mips1` pipeline.

**Practical conclusion:** `reserveCapacity`-style mitigation is not a viable path to making
`ports/PS1` run real `JunkbotCore` logic. It was worth doing (real perf win, ruled out the
growth-copy bug specifically), but the surface area of "which `Array`/`Dictionary` operations
are safe on this target" is larger and less predictable than initially hoped — each fix so far
has uncovered a new failure a few calls later, not converged toward a working state. Further
progress most likely requires either the upstream miscompilation(s) fixed, or (if the game
needs to ship before that happens) `ports/PS1`-specific game-state code written against a
hand-rolled fixed-capacity container backed directly by `UnsafeMutableRawPointer`/
`UnsafeMutableBufferPointer` (proven reliable in this document's very first tests) instead of
`Array`/`Dictionary` at all — which likely means a PS1-specific fork of the parts of
`GameEngine`/`Collision`/`Input`/`RenderList` that touch these collections, not something
achievable by patching `Sources/JunkbotCore` in place without affecting every other port.

## Update 4: `InlineArray` is a confirmed viable escape hatch

`~/Developer/swift-embedded-ps1`'s `Sources/ArrayTests/Main.swift` (test 7) confirms
`InlineArray<count, Element>` (SE-0453) works correctly on this exact toolchain/target:
fixed-size, inline storage, no heap allocation, no COW, no growth — so it never touches the
buffer-class machinery bugs #1/#2 live in. Verified in DuckStation: literal init, subscript
writes, subscript reads, and a full iteration all produced the correct result.

This means "hand-rolled fixed-capacity container" above doesn't need to be built from raw
`UnsafeMutableBufferPointer` manually — `InlineArray<N, Element>` plus a manually-tracked
`count` gives the same fixed-upper-bound shape with much less unsafe code, e.g. something like:

```swift
struct FixedArray<let N: Int, Element> {
  var storage: InlineArray<N, Element>
  var count: Int = 0
  mutating func append(_ e: Element) { storage[count] = e; count += 1 }
  // iterate via `for i in 0..<count { ... storage[i] ... }`, swap-remove, etc.
}
```

This is still a real, non-trivial fork: every `JunkbotCore` collection this port touches
(`entities`, `wind`, `laserBeams`, `entitiesByTopY`/`entitiesByBottomY`, `RenderFrame.commands`,
the various per-call working arrays in `Collision.swift`/`Input.swift`) would need a concrete
maximum size chosen up front and a rewrite against this shape instead of `Array`/`Dictionary` —
not something achievable by patching `Sources/JunkbotCore` in place without affecting every
other port. But it's now a proven-working path rather than a hypothetical one.

## Update 5: a THIRD bug, unrelated to Array entirely — global `let` pointer-cast initializers hang

At the user's request, `ports/PS1` was descoped further: drop `GameState`/`GameEngine`
entirely (temporarily) and just statically render a hardcoded viewport (literal sprite
IDs/coordinates, no `Entity`, no simulation, no input) to validate the rendering pipeline in
isolation. This uncovered a bug that has **nothing to do with `Array`/`Dictionary`**:

```swift
// Hangs forever as a global:
let spritePixels: UnsafePointer<UInt8> =
  UnsafeRawPointer(ps1_asset_sprites_bin()!).assumingMemoryBound(to: UInt8.self)

// The exact same expression, as a local inside a function -- works perfectly:
func renderStaticViewport() {
  let spritePixels: UnsafePointer<UInt8> =
    UnsafeRawPointer(ps1_asset_sprites_bin()!).assumingMemoryBound(to: UInt8.self)
  // ... reads through spritePixels here are all correct ...
}
```

**Isolation, in order:**
1. A stub `renderWorld` with an empty body still hung — proved the bug wasn't in rendering
   logic at all.
2. Removing the call to `renderWorld` entirely and just calling a debug print twice in a row
   *still* hung, as long as `GameState`/`FixedArray<64, Entity>`/`PS1RenderList.swift` were
   present in the source directory — this looked at first like it might implicate
   `FixedArray<64, Entity>`'s `InlineArray(repeating:)` init (a real struct-copy, unlike the
   small `Dummy` struct already verified safe).
3. Descoping further (removing `GameState` etc. from the build entirely, per the user's
   request) and rebuilding from a minimal stub renderer isolated it precisely: a plain buffer
   clear + `LoadImage` upload + flip, with zero sprite code, ran perfectly at 60 FPS. Adding
   back sprite-table lookups (`spriteDataOffsetTable`/`spriteWidthTable`/`spriteHeightTable`)
   alone also worked fine (confirmed via a debug color swatch). Only adding back the pixel-blit
   loop that dereferences `spritePixels` hung.
4. Bisecting *that* found the hang occurred on the very first access of `spritePixels` — i.e.
   during its lazy global initialization, before any loop ran.
5. Ruled out "lazy global init calling a real C function is broken in general": a global `let`
   initialized by calling `ps1_world_framebuffer()` (a proven-working, non-inline C function
   returning an already-typed `uint16_t*`, no cast needed) worked fine as a global.
6. Ruled out "`static inline` C functions can't be called from a global initializer": added a
   non-inline equivalent of `ps1_asset_sprites_bin()` — still hung as a global.
7. Isolated it to the pointer-cast chain itself: `UnsafeRawPointer(ptr!).assumingMemoryBound(to:)`
   hangs as a global initializer, but the identical expression works immediately when it's a
   local variable instead.

**Fix:** compute `spritePixels` fresh inside `renderStaticViewport()` every frame instead of
once as a global `let`. This is cheap (one C call + a pointer cast, no allocation) and, once
applied, produced the first successful sprite render on this port — a row of colored bricks
and Junkbot, rendered correctly, running at a real framerate (not hanging) in DuckStation.

**Practical implication:** this is a THIRD, independent codegen bug on this target, distinct
from the two `Array`-growth bugs above. The common thread across all three is state that's
supposed to persist across calls (an `Array`'s buffer, a lazily-initialized global) rather
than being freshly computed on the stack every time — consistent with this backend having
some kind of systemic issue with values that need to survive past a single expression's
evaluation, not just `Array` specifically. **General guidance going forward for this target:**
prefer local computation over global `let`s with non-trivial initializers wherever the cost of
recomputing is cheap (as it is for a pointer + cast), until this is fixed upstream.

## Update 6: the actual root cause — `ll`/`sc` don't exist on MIPS-I, and three different
Swift runtime mechanisms rely on them

Everything above (Updates 1-5) was diagnosed by working *around* the symptoms one call site at
a time: reserve capacity up front, avoid `removeAll`, avoid binding a global `Array` to a local,
compute pointers locally instead of as globals. That produced a working but severely
restricted PS1-local reimplementation (`GameState`/`FixedArray`/`PS1DynArray`, since removed —
see git history) that duplicated `GameEngine`/`RenderList`/`EntityFactory` instead of using
them directly, because the real versions use `Array`/`Dictionary` throughout.

The actual root cause, found by disassembling the compiled `.elf` and single-stepping under
GDB (DuckStation ships a built-in gdbserver; Homebrew's `gdb` was built with
`--enable-targets=all`, which includes `mips:3000`, so `set architecture mips:3000` + `target
remote localhost:2345` works despite gdb never being packaged specifically for the PS1):

**`swift_retain`/`swift_release` compile to real LLVM `atomicrmw add`/`atomicrmw sub`
instructions**, which the Mips backend lowers to `ll`/`sc` (Load-Linked/Store-Conditional) —
mandatory for a correct atomic read-modify-write on MIPS. **`ll`/`sc` don't exist on MIPS-I**
(the PS1's R3000A) even when compiling with `-mcpu=mips1`; LLVM's MIPS-I support is documented
as "highly experimental" (`llc -mattr=help`) and doesn't gate this lowering on the actual ISA
level. On this target, executing `sc` never reports success, so the retry loop inside
`swift_retain`/`swift_release` spins forever — a genuine CPU livelock, not a crash, which is
why it looked for so long like "Array operations hang," since almost anything nontrivial
touches ARC eventually.

**Fix, part 1 — `-assume-single-threaded`:** this `swift-frontend` flag (confirmed present via
`-help-hidden`) makes IRGen emit plain non-atomic retain/release instead of atomic RMW. Verified
by disassembling `swift_retain`/`swift_release` before/after: before, real `ll`/`sc` pairs;
after, a tail-call into a small non-atomic helper. This alone fixed every `Array` hang from
Updates 1-2.

**Fix, part 2 — the atomics weren't only in `swift_retain`/`swift_release`.** After fixing
those two entry points, dozens of *other* functions still contained `ll`/`sc`: every inlined
copy-on-write uniqueness check, `Array`'s `_consumeAndCreateNew`/`growForAppend`, `Dictionary`'s
`_NativeDictionaryV.copy`/`_DictionaryStorageC.allocate`, `swift_nonatomic_release` (despite the
name), `swift_releaseBox`, `swift_release_n`, `__swift_initWithCopy_strong`, etc. —
`-assume-single-threaded` only changes the two named runtime entry points, not every inlined
refcount/uniqueness check IRGen emits elsewhere. Rather than chase each one individually,
`ports/PS1/Support/fix_atomics.py` mechanically rewrites the emitted `.ll` (between
`swift-frontend -emit-ir` and `llc`, see `compile-swift.sh`): every `atomicrmw`/`cmpxchg`
becomes a plain `load` + arithmetic/compare + `store` (single-threaded target, real atomicity
buys nothing), and every `load atomic`/`store atomic` has its ordering qualifier stripped.
After this, the whole binary has zero `ll`/`sc` instructions (confirmed via `llvm-objdump -d |
grep`).

**Fix, part 3 — `swift_once` is a *different* runtime function with the *same* underlying bug.**
With retain/release fixed, constructing `GameEngine()` still hung — `GameEngine.init()` calls
`entitiesByTopY.reserveCapacity(64)` on a `[Int32: [Int]]` `Dictionary`, and any `Dictionary`/
`Set` operation needs a lazily-initialized hash seed (`Hasher._seed`), gated by `swift_once`.
GDB showed the CPU stuck in `swift_once`'s "someone else already claimed this token, wait for
them" spin loop — reached from `Hasher._hash(seed:_:) <- _HashTable.capacity(forScale:) <-
_DictionaryStorage`. That branch should only be reachable with a second real thread; on this
single-threaded target the only way to reach it is the *same* logical call recursing into
`swift_once` for the same token before the outer call finishes — a self-deadlock, and
`-assume-single-threaded`/the IR rewrite don't touch it since `swift_once`'s CAS (`ll`/`sc`
again) is a separate, IRGen-emitted `weak_odr` symbol, not something that goes through
`atomicrmw`/plain retain-release codegen.

Fix: `swift_once` is `weak_odr` (confirmed via `nm`) and not defined in
`libswiftEmbeddedPlatformPOSIX.a` — it's baked directly into every compiled module, the same as
`swift_retain`/`swift_release` were. A weak symbol can be shadowed by a strong definition
elsewhere at link time — exactly the mechanism this port's bump allocator already uses to
override libc.a's `malloc`/`free`/`posix_memalign`. `common/shim.c` now defines a plain,
non-atomic `swift_once`: claim with an ordinary (non-atomic) compare, run the initializer, mark
done. If the initializer recursively re-enters the same predicate (the exact deadlock
scenario), the inner call just returns without blocking or re-running the initializer — the
recursive caller reads whatever's currently in the not-yet-fully-initialized storage (typically
still zero), which is harmless for a hash seed on an offline single-player game.

With all three fixes in place, `Set`/`Dictionary` work completely (verified with a standalone
`Set<Int>` insert/contains/iterate test, isolated from `GameEngine` entirely) and `GameEngine()`
constructs and runs normally.

## Update 7: a fourth, unrelated failure mode — checked `%` traps DuckStation's recompiler

With Updates 1-6 fixed, `GameEngine`/`RenderList`/`EntityFactory` could finally be used
directly (no more PS1-local `GameState`/`FixedArray` reimplementation) — but the first call to
`buildRenderFrame()` still hung. Bisected with on-screen (`ps1_draw_text`) and SIO
(`ps1_log`/`puts`, surfaced via DuckStation's "Redirect SIO to TTY" debug option, or by running
DuckStation's actual Mach-O binary directly from a terminal instead of via `open -a` so its
stdout has somewhere to go) checkpoints sprinkled through `RenderList.swift`'s call chain, down
to a single line in `junkbotFrame()`:

```swift
let frame = keyframes[Int(e.animationFrame) % keyframes.count]
```

With `e.animationFrame == 0` and `keyframes.count == 10` (confirmed by printing both values
immediately beforehand), this should be entirely inert — but execution never returned from it.
Disassembly shows Swift's checked `%` lowers to the standard MIPS-I-safe sequence (`div`,
`teq $divisor, $zero, 0x7` — trap only if the divisor is genuinely zero — then `mfhi`), and the
divisor here is never zero, so the trap should never fire. Yet DuckStation's own log showed its
recompiler failing to read/compile the code page containing this exact sequence
("Instruction read failed... falling back to uncached interpreter"), in a region that had
already been through repeated cache-invalidation churn from BIOS boot. This looks like a
DuckStation recompiler/interpreter edge case specifically around `teq`-then-`mfhi` sequences
under cache-invalidation pressure, not a Swift codegen bug — real MIPS-I hardware has no issue
with `div`/`teq`/`mfhi` (they're base ISA), and `-Ounchecked` (which removes the `teq` trap
entirely, module-wide) made things *worse* (nothing rendered at all, silently — almost
certainly because it also removes `Array` bounds checks that were incidentally load-bearing
elsewhere), so this isn't a "Swift shouldn't trap here" issue either.

**Fix:** replace the checked `%` at this one call site with a manual subtract-based modulo
(`while idx >= count { idx -= count }`), which never emits `div`/`teq`/`mfhi` at all. Harmless
on every other port (`keyframes.count` is always a small single-digit constant, so the loop
runs at most a couple of iterations). This is a targeted, minimal patch to shared
`RenderList.swift` — not a reason to avoid `%` everywhere in `JunkbotCore`; the other four `%`
uses in `junkbotFrame` (dying/water-dying/eating/shield-donning animation-frame cycling) are
unexercised by this port's v1 test level and haven't been confirmed to hit the same issue.

**Result:** with all four fixes applied, the full shared `GameEngine`/`RenderList` render
pipeline works end-to-end on this target — bricks and Junkbot's sprite render correctly, at a
real framerate, using the exact same `Sources/JunkbotCore` every other port uses. No PS1-local
`GameState`/`FixedArray`/`PS1DynArray` reimplementation is needed anymore.
