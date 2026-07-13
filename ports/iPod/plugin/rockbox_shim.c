/***************************************************************************
 *
 * rockbox_shim.c -- everything Embedded Swift's armv4t output needs that a
 * Rockbox plugin doesn't otherwise have. The complete undefined-symbol
 * surface of libjunkbot.a (audited by scripts/check-undefined.sh) is:
 *
 *   allocator   posix_memalign, free              -> TLSF over plugin buffer
 *   atomics     __atomic_*_4                      -> plain load/store (below)
 *   mem helpers memcpy/memset/memmove, __aeabi_*  -> small local loops
 *   hardening   __stack_chk_guard/__stack_chk_fail
 *   libm        floor/ceil/round (double, the grid math the engine's drag/
 *               collision paths use) + float variants; __aeabi_[fd]* soft-
 *               float arithmetic and __clzsi2/__aeabi_[u]idiv come from libgcc
 *               at link time
 *   entropy     arc4random_buf (Embedded runtime hashing seed)
 *
 * THREADING INVARIANT: all Swift code runs on the plugin's main thread, and
 * any eventual PCM mixer callback (IRQ context) is pure C and never touches
 * Swift objects. That is the entire justification for the non-atomic
 * __atomic_* implementations: ARMv4T has no atomic instructions, so the
 * compiler emits these libcalls for ARC refcounting and swift_once, and on a
 * single core with single-threaded Swift, plain accesses are exactly correct.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 ****************************************************************************/

#include "plugin.h"
#include "tlsf.h"          /* lib/tlsf; linked via $(TLSFLIB) in junkbot.make */
#include "rockbox_shim.h"

/* ------------------------------------------------------------------------ */
/* Allocator: TLSF pool over the plugin buffer. Real free() is required --   */
/* the engine churns Entity arrays and render-command lists every frame.     */
/* sprites.bin is deliberately NOT here: it's ~5.6MB, far larger than the    */
/* plugin buffer, so junkbot.c loads it into the audio buffer instead (see   */
/* junkbot_audio_load); this pool is purely the Swift heap.                  */
/* ------------------------------------------------------------------------ */

#define MIN_ARENA (64 * 1024)

int junkbot_shim_init(void)
{
    size_t size = 0;
    void *arena = rb->plugin_get_buffer(&size);

    if (arena == NULL || size < MIN_ARENA)
        return -1;

    return init_memory_pool(size, arena) == (size_t)-1 ? -1 : 0;
}

/* Swift's embedded allocator asks for posix_memalign(&p, align, size) and
 * releases with free(). TLSF has no aligned variant, so over-allocate and
 * stash the block base one word below the aligned pointer; free() reads it
 * back. Every heap pointer Swift ever frees came from here, so the scheme
 * is self-consistent. */
int posix_memalign(void **memptr, size_t alignment, size_t size)
{
    unsigned char *base, *aligned;

    if (alignment < sizeof(void *))
        alignment = sizeof(void *);

    base = tlsf_malloc(size + alignment + sizeof(void *));
    if (base == NULL)
        return 12; /* ENOMEM */

    aligned = (unsigned char *)
        (((uintptr_t)base + sizeof(void *) + alignment - 1) & ~(uintptr_t)(alignment - 1));
    ((void **)aligned)[-1] = base;
    *memptr = aligned;
    return 0;
}

void free(void *ptr)
{
    if (ptr != NULL)
        tlsf_free(((void **)ptr)[-1]);
}

/* Same stash scheme so a stray malloc()/calloc() stays free()-compatible. */
void *malloc(size_t size)
{
    void *p = NULL;
    posix_memalign(&p, sizeof(void *) * 2, size ? size : 1);
    return p;
}

void *calloc(size_t nmemb, size_t size)
{
    size_t total = nmemb * size;
    void *p = malloc(total);
    if (p != NULL)
        memset(p, 0, total);
    return p;
}

/* ------------------------------------------------------------------------ */
/* Atomics (see THREADING INVARIANT above).                                  */
/* ------------------------------------------------------------------------ */

unsigned __atomic_load_4(const volatile void *ptr, int memorder)
{
    (void)memorder;
    return *(const volatile unsigned *)ptr;
}

void __atomic_store_4(volatile void *ptr, unsigned val, int memorder)
{
    (void)memorder;
    *(volatile unsigned *)ptr = val;
}

unsigned __atomic_fetch_add_4(volatile void *ptr, unsigned val, int memorder)
{
    volatile unsigned *p = ptr;
    unsigned old = *p;
    (void)memorder;
    *p = old + val;
    return old;
}

unsigned __atomic_fetch_sub_4(volatile void *ptr, unsigned val, int memorder)
{
    volatile unsigned *p = ptr;
    unsigned old = *p;
    (void)memorder;
    *p = old - val;
    return old;
}

unsigned __atomic_exchange_4(volatile void *ptr, unsigned val, int memorder)
{
    volatile unsigned *p = ptr;
    unsigned old = *p;
    (void)memorder;
    *p = val;
    return old;
}

bool __atomic_compare_exchange_4(volatile void *ptr, void *expected,
                                 unsigned desired, bool weak,
                                 int success_order, int failure_order)
{
    volatile unsigned *p = ptr;
    unsigned *e = expected;
    (void)weak; (void)success_order; (void)failure_order;
    if (*p == *e) {
        *p = desired;
        return true;
    }
    *e = *p;
    return false;
}

/* ------------------------------------------------------------------------ */
/* mem functions: LLVM emits direct calls to both the C names and the ARM    */
/* EABI helpers (__aeabi_memclr & friends); a plugin links neither libc nor  */
/* the core's versions, so provide word-at-a-time locals.                    */
/* ------------------------------------------------------------------------ */

void *memcpy(void *dst, const void *src, size_t n)
{
    unsigned char *d = dst;
    const unsigned char *s = src;

    if ((((uintptr_t)d | (uintptr_t)s) & 3) == 0) {
        while (n >= 4) {
            *(unsigned *)d = *(const unsigned *)s;
            d += 4; s += 4; n -= 4;
        }
    }
    while (n--)
        *d++ = *s++;
    return dst;
}

void *memmove(void *dst, const void *src, size_t n)
{
    unsigned char *d = dst;
    const unsigned char *s = src;

    if (d <= s || d >= s + n)
        return memcpy(dst, src, n);
    d += n; s += n;
    while (n--)
        *--d = *--s;
    return dst;
}

void *memset(void *dst, int c, size_t n)
{
    unsigned char *d = dst;
    unsigned word = (unsigned char)c;

    word |= word << 8;
    word |= word << 16;
    if (((uintptr_t)d & 3) == 0) {
        while (n >= 4) {
            *(unsigned *)d = word;
            d += 4; n -= 4;
        }
    }
    while (n--)
        *d++ = (unsigned char)c;
    return dst;
}

int memcmp(const void *a, const void *b, size_t n)
{
    const unsigned char *pa = a, *pb = b;
    while (n--) {
        if (*pa != *pb)
            return (int)*pa - (int)*pb;
        pa++; pb++;
    }
    return 0;
}

void __aeabi_memcpy(void *dst, const void *src, size_t n)  { memcpy(dst, src, n); }
void __aeabi_memcpy4(void *dst, const void *src, size_t n) { memcpy(dst, src, n); }
void __aeabi_memcpy8(void *dst, const void *src, size_t n) { memcpy(dst, src, n); }
void __aeabi_memmove(void *dst, const void *src, size_t n) { memmove(dst, src, n); }
void __aeabi_memmove4(void *dst, const void *src, size_t n){ memmove(dst, src, n); }
void __aeabi_memmove8(void *dst, const void *src, size_t n){ memmove(dst, src, n); }
/* Note the EABI argument order: (dest, size, value). */
void __aeabi_memset(void *dst, size_t n, int c)  { memset(dst, c, n); }
void __aeabi_memset4(void *dst, size_t n, int c) { memset(dst, c, n); }
void __aeabi_memset8(void *dst, size_t n, int c) { memset(dst, c, n); }
void __aeabi_memclr(void *dst, size_t n)  { memset(dst, 0, n); }
void __aeabi_memclr4(void *dst, size_t n) { memset(dst, 0, n); }
void __aeabi_memclr8(void *dst, size_t n) { memset(dst, 0, n); }

/* ------------------------------------------------------------------------ */
/* Stack protector (swiftc emits it by default).                             */
/* ------------------------------------------------------------------------ */

unsigned long __stack_chk_guard = 0xcafe0a75UL;

void __stack_chk_fail(void)
{
    rb->splash(HZ * 2, "junkbot: stack smashed");
    for (;;)
        rb->yield();
}

/* ------------------------------------------------------------------------ */
/* libm: Rockbox has none. The engine's drag-to-grid and collision math      */
/* rounds Doubles (floor/ceil/round); the soft-float arithmetic under these  */
/* (__aeabi_d*/__aeabi_i2d/__aeabi_d2lz ...) comes from libgcc at link time. */
/* The float variants + sinf/cosf/fmodf are provided for completeness / the  */
/* eventual audio phase, and are cheap.                                      */
/* ------------------------------------------------------------------------ */

double floor(double x)
{
    double f;
    /* Already integral (or NaN/Inf) at/above 2^52. */
    if (x != x || x >= 4503599627370496.0 || x <= -4503599627370496.0)
        return x;
    f = (double)(long long)x;
    return (f > x) ? f - 1.0 : f;
}

double ceil(double x)
{
    double f;
    if (x != x || x >= 4503599627370496.0 || x <= -4503599627370496.0)
        return x;
    f = (double)(long long)x;
    return (f < x) ? f + 1.0 : f;
}

double round(double x)
{
    return (x >= 0.0) ? floor(x + 0.5) : ceil(x - 0.5);
}

float floorf(float x)
{
    float f;
    if (x != x || x >= 8388608.0f || x <= -8388608.0f)
        return x; /* integral beyond 2^23 (or NaN/Inf) */
    f = (float)(int)x;
    return (f > x) ? f - 1.0f : f;
}

float ceilf(float x)
{
    float f;
    if (x != x || x >= 8388608.0f || x <= -8388608.0f)
        return x;
    f = (float)(int)x;
    return (f < x) ? f + 1.0f : f;
}

float roundf(float x)
{
    return (x >= 0.0f) ? floorf(x + 0.5f) : ceilf(x - 0.5f);
}

float fmodf(float x, float y)
{
    float ax = (x < 0.0f) ? -x : x;
    float ay = (y < 0.0f) ? -y : y;

    /* y==0, NaN, or |x| infinite -> NaN. `ax * 0.0f != 0.0f` is false at
     * ax==0 (0*0==0) and true only for a true infinity (inf*0==NaN != NaN). */
    if (y == 0.0f || x != x || y != y || (ax * 0.0f) != 0.0f)
        return 0.0f / 0.0f;
    if (ax < ay)
        return x;

    {
        int outer = 64;
        while (ax >= ay && outer-- > 0) {
            float t = ay;
            int inner = 64;
            while (ax - t >= t && inner-- > 0)
                t += t;
            ax -= t;
        }
    }
    return (x < 0.0f) ? -ax : ax;
}

float sinf(float x)
{
    const float two_pi  = 6.28318530718f;
    const float pi      = 3.14159265359f;
    const float half_pi = 1.57079632679f;
    float x2, r;
    int negate = 0;

    x = fmodf(x, two_pi);
    if (x != x)
        return x;
    if (x < 0.0f)
        x += two_pi;
    if (x > pi) {
        x -= pi;
        negate = 1;
    }
    if (x > half_pi)
        x = pi - x;

    x2 = x * x;
    r = x * (1.0f + x2 * (-1.0f / 6.0f
              + x2 * (1.0f / 120.0f
              + x2 * (-1.0f / 5040.0f))));
    return negate ? -r : r;
}

float cosf(float x)
{
    return sinf(x + 1.57079632679f);
}

/* ------------------------------------------------------------------------ */
/* Misc runtime gaps.                                                        */
/* ------------------------------------------------------------------------ */

/* Embedded Swift's runtime wants entropy for hashing seeds (same gap the 3DS
 * port fills). Gameplay randomness is independent (the engine's own xorshift),
 * so a tick-seeded xorshift is plenty. */
void arc4random_buf(void *buf, size_t nbytes)
{
    static unsigned state;
    unsigned char *p = buf;

    if (state == 0)
        state = (unsigned)*rb->current_tick | 1;
    while (nbytes--) {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        *p++ = (unsigned char)state;
    }
}

/* Embedded Swift's fatal-error path prints through putchar. Swallow it; the
 * trap that follows is what we'd see anyway. */
int putchar(int c)
{
    return c;
}

/* Fixed-arity debug print for Swift (Embedded Swift can't call varargs). */
void rb_puts(const char *s)
{
#ifdef JUNKBOT_DEBUG
    rb->splash(HZ / 2, s);
#else
    (void)s;
#endif
}

/* Audio trigger (Swift -> C). No-op until the audio phase lands (see
 * ports/iPod/README.md); kept here so libjunkbot.a always links. */
void rb_audio_sfx(int id)
{
    (void)id;
}
