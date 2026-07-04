// C shims for the Wii port.

#include <gccore.h>
#include <errno.h>
#include <malloc.h>
#include <reent.h>
#include <ogc/lwp_watchdog.h>

// The Embedded Swift allocator (swift_slowAlloc) calls posix_memalign, which devkitPPC's newlib
// does not provide. Implement it in terms of memalign, same as
// https://github.com/MillerTechnologyPeru/swift-embedded-wii's common/runtime.c.
int posix_memalign(void **memptr, size_t alignment, size_t size) {
    void *p = memalign(alignment, size);
    if (p == NULL) {
        return ENOMEM;
    }
    *memptr = p;
    return 0;
}

// GX_SetCopyFilter takes the rmode's 2-D sample-pattern and vfilter arrays, which are awkward to
// pass from Swift; wrap the call in C (same shim as the swift-embedded-wii triangle example).
void wii_set_copy_filter(GXRModeObj *rmode) {
    GX_SetCopyFilter(rmode->aa, rmode->sample_pattern, GX_TRUE, rmode->vfilter);
}

// The Swift runtime reads system entropy once at startup to randomize its `Hasher` seed (so
// `Dictionary`/`Set` - both used by GameEngine, e.g. `entitiesByTopY`/`draggingEntityIDs` - aren't
// vulnerable to hash-flooding). devkitPPC's newlib declares `_getentropy_r` as a syscall a libc
// port must supply but doesn't implement one for the Wii, so linking fails without this. There's
// no real hardware entropy source exposed here; `gettick()` (the OS's free-running tick counter)
// is good enough to vary the hash seed run to run, which is all this needs - not a cryptographic
// randomness source.
int _getentropy_r(struct _reent *r, void *buf, size_t buflen) {
    (void)r;
    unsigned char *p = (unsigned char *)buf;
    u32 seed = gettick();
    for (size_t i = 0; i < buflen; i++) {
        seed ^= seed << 13;
        seed ^= seed >> 17;
        seed ^= seed << 5;
        p[i] = (unsigned char)(seed >> (8 * (i % 4)));
    }
    return 0;
}
