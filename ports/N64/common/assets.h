//---------------------------------------------------------------------------------
// assets.h -- extern declarations for the objcopy-embedded asset blobs, plus
// stable-pointer accessors for Swift.
//
// A C global array imports into Swift as a tuple (a *copy*), so
// `withUnsafeBytes(of:)` would only yield a temporary; these accessors return
// the address of the real linked symbol, valid for the program's lifetime.
//
// Unlike ports/3DS/ports/NDS's bin2s-generated `<name>_size` (a real data word
// holding the byte count), this port's Makefile embeds each blob with
// `mips64-elf-objcopy -I binary` and exposes `<name>`/`<name>_end` as ld
// `--defsym` aliases for objcopy's own `_binary_<file>_start`/`_end` symbols --
// so the size here is a pointer difference, not a dereference.
//---------------------------------------------------------------------------------
#ifndef SWIFT_N64_ASSETS_H
#define SWIFT_N64_ASSETS_H

#include <stdint.h>

extern const uint8_t sprites_bin[];
extern const uint8_t sprites_bin_end[];
extern const uint8_t audio_bin[];
extern const uint8_t audio_bin_end[];
extern const uint8_t music_bin[];
extern const uint8_t music_bin_end[];
extern const uint8_t font_bin[];
extern const uint8_t font_bin_end[];

static inline const void *n64_asset_sprites_bin(void) { return sprites_bin; }
static inline uint32_t n64_asset_sprites_bin_size(void) { return (uint32_t)(sprites_bin_end - sprites_bin); }
static inline const void *n64_asset_audio_bin(void) { return audio_bin; }
static inline uint32_t n64_asset_audio_bin_size(void) { return (uint32_t)(audio_bin_end - audio_bin); }
static inline const void *n64_asset_music_bin(void) { return music_bin; }
static inline uint32_t n64_asset_music_bin_size(void) { return (uint32_t)(music_bin_end - music_bin); }
static inline const void *n64_asset_font_bin(void) { return font_bin; }
static inline uint32_t n64_asset_font_bin_size(void) { return (uint32_t)(font_bin_end - font_bin); }

#endif // SWIFT_N64_ASSETS_H
