// assets.h -- extern declarations for the objcopy-embedded asset blobs, plus
// stable-pointer accessors for Swift. Same start/end-pointer convention as
// ports/N64/common/assets.h (llvm-objcopy -I binary produces
// `_binary_<file>_start`/`_end`, aliased here via the Makefile's --defsym).
#ifndef SWIFT_PS1_ASSETS_H
#define SWIFT_PS1_ASSETS_H

#include <stdint.h>

extern const uint8_t sprites_bin[];
extern const uint8_t sprites_bin_end[];

static inline const void *ps1_asset_sprites_bin(void) { return sprites_bin; }
static inline uint32_t ps1_asset_sprites_bin_size(void) { return (uint32_t)(sprites_bin_end - sprites_bin); }

#endif // SWIFT_PS1_ASSETS_H
