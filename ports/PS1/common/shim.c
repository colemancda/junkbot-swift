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
// POSIX stubs for libswiftEmbeddedPlatformPOSIX
// ---------------------------------------------------------------------------

extern void *malloc(size_t size);
extern void  free(void *ptr);

int posix_memalign(void **memptr, size_t alignment, size_t size) {
  void *p = malloc(size);
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

// ---------------------------------------------------------------------------
// Heap init — PSn00bSDK malloc()/InitHeap. 2MB RAM ends at 0x80200000; leave
// ~128KB above the heap ceiling for stack (boot.S starts SP at 0x80200000 and
// grows down), same constant swift-embedded-ps1's Balls example uses.
// ---------------------------------------------------------------------------

extern char _end;

void ps1_init_heap(void) {
  unsigned int start = (unsigned int)&_end;
  int size = (int)(0x801E0000u - start);
  InitHeap((void *)start, size);
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

  setRGB0(&s_buf[0].draw, 24, 8, 64);
  setRGB0(&s_buf[1].draw, 24, 8, 64);
  s_buf[0].draw.isbg = 1;
  s_buf[1].draw.isbg = 1;

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
