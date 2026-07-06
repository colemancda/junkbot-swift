# Upstream bug: Array/ContiguousArray allocation passes a corrupted byte count on `mipsel-none-none-elf`

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
