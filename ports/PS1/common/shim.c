// shim.c — POSIX stubs for libswiftEmbeddedPlatformPOSIX + PSn00bSDK render
// context. Verbatim reuse of the patterns established in
// ~/Developer/swift-embedded-ps1's HelloPS1/Balls examples (see that repo's
// README for why each stub exists).

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <psxgpu.h>
#include <psxsio.h>
#include <psxapi.h>
#include "shim.h"

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

uint32_t debug_last_alignment;
uint32_t debug_last_size;
uint32_t debug_last_result_isnull;

static void debug_hex(char *out, uint32_t v) {
  static const char hex[] = "0123456789ABCDEF";
  out[0] = '0'; out[1] = 'x';
  for (int i = 0; i < 8; i++) out[2 + i] = hex[(v >> ((7 - i) * 4)) & 0xF];
  out[10] = 0;
}

// Draws onto BOTH buffers (two flips) so the line stays visible on whichever
// buffer ends up displayed if execution later hangs -- a single flip only
// guarantees visibility on the buffer that happens to be on-screen at that
// exact parity, which cost real time to figure out empirically.
static void debug_line(int y, const char *label, const char *value) {
  ps1_draw_text(8, y, label);
  if (value) ps1_draw_text(70, y, value);
  ps1_flip();
  ps1_begin_frame();
  ps1_draw_text(8, y, label);
  if (value) ps1_draw_text(70, y, value);
  ps1_flip();
  ps1_begin_frame();
}

int posix_memalign(void **memptr, size_t alignment, size_t size) {
  debug_last_alignment = (uint32_t)alignment;
  debug_last_size = (uint32_t)size;

  void *p = bump_alloc(size, alignment < sizeof(void *) ? sizeof(void *) : alignment);
  debug_last_result_isnull = (p == NULL);

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

int putchar(int c) { AddSIO(c); return c; }

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
