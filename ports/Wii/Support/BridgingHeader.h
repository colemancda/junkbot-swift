// C interop surface for the Wii port. Mirrors the pattern used by
// https://github.com/MillerTechnologyPeru/swift-embedded-wii's examples (helloworld/triangle/
// wiimote): pull in the libogc headers this target needs, then add `static inline` shims for the
// handful of things libogc exposes only as function-like macros, which the Clang importer can't
// turn into callable Swift functions.

#pragma once

#include <stdint.h>
#include <stdlib.h>
#include <malloc.h>
#include <string.h>

#include <gccore.h>
#include <wiiuse/wpad.h>

// MEM_K0_TO_K1 is a function-like macro that maps a cached address into the uncached memory
// window (used for framebuffers/DMA targets). Wrap it so Swift can call it.
static inline void *wii_mem_k0_to_k1(void *ptr) {
    return MEM_K0_TO_K1(ptr);
}

// GX_SetCopyFilter takes the rmode's 2-D sample-pattern/vfilter arrays, which are awkward to pass
// from Swift; defined in Support/shims.c.
void wii_set_copy_filter(GXRModeObj *rmode);

// Typed re-exports of the object-like macro/enum constants used by main.swift, so the Swift side
// sees an unambiguous integer type instead of whatever literal type the Clang importer would
// otherwise infer.
static const int32_t  kGX_TRUE          = GX_TRUE;
static const int32_t  kGX_FALSE         = GX_FALSE;
static const int32_t  kGX_ENABLE        = GX_ENABLE;
static const int32_t  kGX_DISABLE       = GX_DISABLE;
static const int32_t  kGX_CULL_NONE     = GX_CULL_NONE;
static const int32_t  kGX_GM_1_0        = GX_GM_1_0;
static const int32_t  kGX_ORTHOGRAPHIC  = GX_ORTHOGRAPHIC;
static const int32_t  kGX_QUADS         = GX_QUADS;
static const int32_t  kGX_VTXFMT0       = GX_VTXFMT0;
static const int32_t  kGX_VA_POS        = GX_VA_POS;
static const int32_t  kGX_VA_CLR0       = GX_VA_CLR0;
static const int32_t  kGX_DIRECT        = GX_DIRECT;
static const int32_t  kGX_POS_XYZ       = GX_POS_XYZ;
static const int32_t  kGX_F32           = GX_F32;
static const int32_t  kGX_CLR_RGBA      = GX_CLR_RGBA;
static const int32_t  kGX_RGBA8         = GX_RGBA8;
static const int32_t  kGX_TEVSTAGE0     = GX_TEVSTAGE0;
static const int32_t  kGX_TEXCOORDNULL  = GX_TEXCOORDNULL;
static const int32_t  kGX_TEXMAP_NULL   = GX_TEXMAP_NULL;
static const int32_t  kGX_COLOR0A0      = GX_COLOR0A0;
static const int32_t  kGX_PASSCLR       = GX_PASSCLR;
static const int32_t  kGX_PNMTX0        = GX_PNMTX0;
static const int32_t  kGX_ALWAYS        = GX_ALWAYS;
static const uint32_t kVI_NON_INTERLACE = VI_NON_INTERLACE;
static const uint32_t kWPAD_BUTTON_A    = WPAD_BUTTON_A;
static const uint32_t kWPAD_BUTTON_HOME = WPAD_BUTTON_HOME;
static const int32_t  kWPAD_FMT_BTNS_ACC_IR = WPAD_FMT_BTNS_ACC_IR;
