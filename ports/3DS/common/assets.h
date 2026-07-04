//---------------------------------------------------------------------------------
// assets.h -- extern declarations for the bin2s-embedded asset blobs, plus
// stable-pointer accessors for Swift.
//
// A C global array imports into Swift as a tuple (a *copy*), so
// `withUnsafeBytes(of:)` would only yield a temporary; these accessors return
// the address of the real linked symbol, valid for the program's lifetime.
// Symbol names follow bin2s's convention for `sprites.bin` / `audio.bin` / `music.bin`.
//---------------------------------------------------------------------------------
#ifndef SWIFT_3DS_ASSETS_H
#define SWIFT_3DS_ASSETS_H

#include <stdint.h>

extern const uint8_t sprites_bin[];
extern const uint32_t sprites_bin_size;
extern const uint8_t audio_bin[];
extern const uint32_t audio_bin_size;
extern const uint8_t music_bin[];
extern const uint32_t music_bin_size;

static inline const void *ctru_asset_sprites_bin(void) { return sprites_bin; }
static inline uint32_t ctru_asset_sprites_bin_size(void) { return sprites_bin_size; }
static inline const void *ctru_asset_audio_bin(void) { return audio_bin; }
static inline uint32_t ctru_asset_audio_bin_size(void) { return audio_bin_size; }
static inline const void *ctru_asset_music_bin(void) { return music_bin; }
static inline uint32_t ctru_asset_music_bin_size(void) { return music_bin_size; }

#endif // SWIFT_3DS_ASSETS_H
