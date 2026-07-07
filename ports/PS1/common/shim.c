// shim.c — POSIX stubs for libswiftEmbeddedPlatformPOSIX + PSn00bSDK render
// context. Verbatim reuse of the patterns established in
// ~/Developer/swift-embedded-ps1's HelloPS1/Balls examples (see that repo's
// README for why each stub exists).

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <psxgpu.h>
#include <psxsio.h>
#include <psxapi.h>
#include <psxpad.h>
#include "shim.h"
#include "assets.h"

// ---------------------------------------------------------------------------
// Pad input -- see shim.h's doc comment.
// ---------------------------------------------------------------------------

static uint8_t s_pad_buf[34];  // BIOS continuous-poll scratch (port 1 only)

void ps1_init_pad(void) {
  InitPAD(s_pad_buf, sizeof(s_pad_buf), 0, 0);
  StartPAD();
  // Matches common PSn00bSDK sample code: without this, the BIOS driver's
  // default VSync-latched clearing behavior can leave held-button bits
  // stale between reads on some BIOS revisions.
  ChangeClearPAD(0);
}

uint16_t ps1_pad_held(void) {
  PADTYPE *pad = (PADTYPE *)s_pad_buf;
  if (pad->stat != 0) return 0;  // no pad connected / not ready this frame
  return (uint16_t)~pad->btn;
}

// Debug-only: a NON-inline equivalent of assets.h's `static inline
// ps1_asset_sprites_bin()`, to test whether the `static inline` declaration
// itself (as opposed to a normal externally-linked function) is what breaks
// when called from a Swift global `let` initializer.
const uint8_t *ps1_asset_sprites_bin_noninline(void) { return sprites_bin; }

// ---------------------------------------------------------------------------
// Heap: a bump allocator, NOT PSn00bSDK's InitHeap/malloc.
//
// The R3000A (unlike most modern CPUs) hard-faults on misaligned word/half
// -word access -- there's no hardware fixup. PSn00bSDK's malloc gives no
// alignment guarantee beyond whatever its internal block header happens to
// leave, and Swift's Array/class heap allocations request specific
// alignments (via posix_memalign) that the runtime actually depends on, not
// just as a performance hint. Ignoring the requested alignment (as a naive
// `posix_memalign` -> `malloc` passthrough does) produced a misaligned
// pointer that later faulted into the (unhandled) exception vector --
// silently, with no crash log, just an infinite loop at address 0 (confirmed
// by bisection: `GameEngine()` alone worked, but the first `Array.append`
// after it hung with the display frozen at 0 FPS).
//
// A bump allocator sidesteps the mismatch entirely: it's the only allocator
// in the image (defining `malloc`/`free`/`posix_memalign` here means
// libpsxgpu's/libc's own malloc.o is never pulled out of the .a archives, by
// normal linker symbol resolution), and it can always honor whatever
// alignment is requested. `free` is a no-op (this v1 port never frees -- the
// per-level entity arrays are small and rebuilt in place, so the leak is
// bounded by level-load count, not by frames).
// ---------------------------------------------------------------------------

extern char _end;
static uint8_t *s_heap_next;
static uint8_t *s_heap_top;

static void *bump_alloc(size_t size, size_t alignment) {
  uintptr_t p = (uintptr_t)s_heap_next;
  p = (p + (alignment - 1)) & ~(uintptr_t)(alignment - 1);
  if ((uint8_t *)(p + size) > s_heap_top) return NULL; // out of memory
  s_heap_next = (uint8_t *)(p + size);
  return (void *)p;
}

void *malloc(size_t size) { return bump_alloc(size, 8); }
void  free(void *ptr) { (void)ptr; }

int posix_memalign(void **memptr, size_t alignment, size_t size) {
  void *p = bump_alloc(size, alignment < sizeof(void *) ? sizeof(void *) : alignment);
  if (!p) return 12; // ENOMEM
  *memptr = p;
  return 0;
}

void arc4random_buf(void *buf, size_t nbytes) {
  static uint32_t state = 0xDEADBEEF;
  uint8_t *p = (uint8_t *)buf;
  for (size_t i = 0; i < nbytes; i++) {
    state = state * 1664525u + 1013904223u;
    p[i] = (uint8_t)(state >> 24);
  }
}

// PSn00bSDK's stdio.h declares `void putchar(int)` (non-standard return type)
// -- match it exactly now that this file includes <stdio.h> for puts().
void putchar(int c) { AddSIO(c); }

void ps1_log(const char *message) { puts(message); }

void exit(int code) { (void)code; while (1) {} }

uintptr_t __stack_chk_guard = 0xDEADC0DE;
void __stack_chk_fail(void) { while (1) {} }

// psn00bsdk's libc has no libm -- JunkbotCore's worldToCanvas/hash-table
// scaling use Double floor/ceil; the game's coordinate ranges are small
// (well within a long long), so a simple truncate-and-adjust is exact.
double floor(double x) {
  double t = (double)(long long)x;
  if (t > x) t -= 1.0;
  return t;
}

double ceil(double x) {
  double t = (double)(long long)x;
  if (t < x) t += 1.0;
  return t;
}

// ---------------------------------------------------------------------------
// swift_once override -- see KNOWN_ISSUES.md.
//
// Swift's IRGen emits `swift_once` directly into every module as a `weak_odr`
// symbol (confirmed via `nm`/IR dump -- it's not in libswiftEmbeddedPlatformPOSIX.a,
// it's baked into swiftlib.o itself), the same pattern already exploited here for
// `malloc`/`free`/`posix_memalign` (this file's bump allocator overrides the
// weak libc.a versions by simple strong-symbol shadowing at link time).
//
// The generated `swift_once` claims a "who's initializing this" token via
// `ll`/`sc` (Load-Linked/Store-Conditional) -- which don't exist on MIPS-I
// (the PS1's R3000A), the same instruction pair whose absence caused the
// `swift_retain`/`swift_release` hangs fixed by `-assume-single-threaded`.
// That flag has no effect on `swift_once`, though: it only changes ARC
// codegen. Any `Dictionary`/`Set` operation needs a lazily-initialized hash
// seed (`Hasher._seed`), gated by exactly this `swift_once` -- so
// constructing so much as one `Dictionary` deadlocks on this target.
//
// Confirmed via GDB (DuckStation's built-in gdbserver, `mips:3000` target in
// a Homebrew-installed cross-capable gdb): stuck in swift_once's "someone
// else already claimed this, wait for them" spin loop, reached from
// `Hasher._hash(seed:_:) <- _HashTable.capacity(forScale:) <-
// _DictionaryStorage` -- i.e. the SAME logical call recursing into
// `swift_once` for the same token before the outer call finishes, which can
// only deadlock on a single-threaded target (there's no other thread that
// could ever finish and unblock the wait).
//
// This target only ever runs one thread, so the real fix is trivial: a
// plain, non-atomic check-and-run. If the initializer recursively re-enters
// this same predicate (the exact scenario that deadlocks upstream), the
// inner call sees "in progress" and just returns without running fn again
// or blocking -- the recursive caller reads whatever's currently in the
// target's storage (typically still its zero-initialized value, e.g. an
// all-zero hash seed), which is semantically harmless here: a
// single-player, non-networked puzzle game has no need for
// hash-flooding-attack resistance, so a weaker/degenerate seed costs
// nothing. Matches the exact signature swift_once's callers expect (see the
// `jalr $25`/`move $4,$6` calling convention in the disassembly this was
// reverse-engineered from: predicate, fn, context, in that order, void fn
// itself taking just the context pointer).
typedef long swift_once_t;

void swift_once(swift_once_t *predicate, void (*fn)(void *), void *context) {
  if (*predicate == 0) {
    *predicate = 1;   // claim it -- blocks recursive re-entry from re-running fn
    fn(context);
    *predicate = -1;  // done -- matches the `bltz`/`bgez` fast-path check upstream
  }
}

// ---------------------------------------------------------------------------
// Heap init — bounds for the bump allocator above. 2MB RAM ends at
// 0x80200000; leave ~128KB above the heap ceiling for stack (boot.S starts
// SP at 0x80200000 and grows down), same constant swift-embedded-ps1's Balls
// example used for its (different) InitHeap-based allocator.
// ---------------------------------------------------------------------------

void ps1_init_heap(void) {
  s_heap_next = (uint8_t *)&_end;
  s_heap_top = (uint8_t *)0x801E0000u;
}

// ---------------------------------------------------------------------------
// Render context (mirrors swift-embedded-ps1's HelloPS1/shim.c)
// ---------------------------------------------------------------------------

#define OT_LENGTH  16
#define BUFFER_LEN 8192

typedef struct {
  DISPENV  disp;
  DRAWENV  draw;
  uint32_t ot[OT_LENGTH];
  uint8_t  prim[BUFFER_LEN];
} RenderBuffer;

static RenderBuffer s_buf[2];
static uint8_t     *s_next;
static int          s_active;

void ps1_init_display(void) {
  ResetGraph(0);
  FntLoad(960, 0);

  SetDefDispEnv(&s_buf[0].disp, 0,   0, 320, 240);
  SetDefDrawEnv(&s_buf[0].draw, 0, 240, 320, 240);
  SetDefDispEnv(&s_buf[1].disp, 0, 240, 320, 240);
  SetDefDrawEnv(&s_buf[1].draw, 0,   0, 320, 240);

  // isbg's clear-rect primitive lives in the ordering table and executes at
  // DrawOTag time (ps1_flip), which is *after* ps1_present_world's LoadImage2
  // upload for this frame -- leaving it on would wipe the just-uploaded world
  // raster every frame. Renderer.swift clears the RAM framebuffer itself
  // (see clearWorld in source/Renderer.swift) before blitting, so the GPU
  // clear isn't needed.
  s_buf[0].draw.isbg = 0;
  s_buf[1].draw.isbg = 0;

  s_active = 0;
  s_next   = s_buf[0].prim;
  ClearOTagR(s_buf[0].ot, OT_LENGTH);

  PutDispEnv(&s_buf[0].disp);
  PutDrawEnv(&s_buf[0].draw);
  SetDispMask(1);
}

void ps1_begin_frame(void) {
  // no-op for now; kept as a hook so Swift's per-frame code has a clear
  // "start of frame" call site once real primitives are added (task #3).
}

void ps1_draw_text(int x, int y, const char *text) {
  s_next = (uint8_t *)FntSort(&s_buf[s_active].ot[0], s_next, x, y, text);
}

// Debug-only (see shim.h) -- hand-rolled decimal formatting, no libc sprintf
// dependency, so it can't itself be a new source of doubt while bisecting an
// Array-growth bug.
void ps1_draw_int(int x, int y, const char *label, int value) {
  char buf[48];
  int n = 0;
  while (label[n] && n < 32) { buf[n] = label[n]; n++; }
  if (value == 0) {
    buf[n++] = '0';
  } else {
    char digits[12];
    int d = 0;
    int v = value;
    int neg = v < 0;
    if (neg) v = -v;
    while (v > 0) { digits[d++] = '0' + (v % 10); v /= 10; }
    if (neg) buf[n++] = '-';
    while (d > 0) buf[n++] = digits[--d];
  }
  buf[n] = 0;
  s_next = (uint8_t *)FntSort(&s_buf[s_active].ot[0], s_next, x, y, buf);
}

// ---------------------------------------------------------------------------
// World framebuffer (see shim.h's doc comment)
// ---------------------------------------------------------------------------

#define FB_W 320
#define FB_H 240

static uint16_t s_world_fb[FB_W * FB_H];

uint16_t *ps1_world_framebuffer(void) { return s_world_fb; }

void ps1_present_world(void) {
  RECT r = s_buf[s_active].draw.clip;
  r.w = FB_W;
  r.h = FB_H;
  LoadImage(&r, (const uint32_t *)s_world_fb);
  DrawSync(0);
}

void ps1_flip(void) {
  DrawSync(0);
  VSync(0);

  RenderBuffer *draw = &s_buf[s_active];
  RenderBuffer *disp = &s_buf[s_active ^ 1];

  PutDispEnv(&disp->disp);
  PutDrawEnv(&draw->draw);
  DrawOTag(&draw->ot[OT_LENGTH - 1]);

  s_active ^= 1;
  s_next    = disp->prim;
  ClearOTagR(disp->ot, OT_LENGTH);
}
