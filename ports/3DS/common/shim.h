//---------------------------------------------------------------------------------
// shim.h -- shared C support for the Junkbot 3DS port.
//
// Three jobs:
//   1. Fixed-arity wrappers around the console's variadic printf, which
//      Embedded Swift can import but not call directly.
//   2. NDSP (audio DSP) playback -- Embedded Swift can't touch the
//      `ndspWaveBuf` tagged union directly, so this owns wave-buffer storage
//      and the linear-memory copies NDSP's DMA requires (see shim.c).
//   3. A software-rasterizer present step: the bottom LCD's framebuffer is
//      stored column-major (physically a portrait 240x320 panel rotated for
//      landscape display), so writing our row-major 320x240 canvas straight
//      into it would come out sideways -- ctru_present_bottom transposes it.
//---------------------------------------------------------------------------------
#ifndef SWIFT_3DS_SHIM_H
#define SWIFT_3DS_SHIM_H

#include <stdint.h>

// printf(fmt, a)        -- one 32-bit argument (use for %d, %u, %x, ...).
void ctru_printf_1i(const char *fmt, int a);

// printf(fmt, a, b)     -- two 32-bit arguments.
void ctru_printf_2i(const char *fmt, int a, int b);

// printf("%.*s", len, s): print a non-NUL-terminated run of bytes (Swift
// StaticString / String UTF-8 buffers).
void ctru_print_len(const char *s, int len);

// Print an already-formatted string (no varargs).
void ctru_puts(const char *s);

// --- Audio (NDSP) ------------------------------------------------------------

// Initializes NDSP and copies the bin2s-embedded audio.bin/music.bin blobs
// into linear (DSP-DMA-safe) memory. Call once at startup.
void ctru_audio_init(void);

// Plays `nsamples` signed 16-bit PCM mono samples starting at the given
// element offset into audio.bin (`bank` 0) or music.bin (`bank` 1) on NDSP
// channel `channel`, looping the whole buffer forever if `loop` is set.
void ctru_play_pcm16(int channel, int bank, unsigned sampleOffset, unsigned sampleCount,
                      float rate, int loop);

// Stops whatever is playing (if anything) on the given NDSP channel.
void ctru_stop_channel(int channel);

// --- Bottom-screen present -----------------------------------------------------

// Transposes `canvas` (320x240, row-major, RGB565) into the bottom screen's
// current hardware framebuffer (240x320, column-major) and flips it.
void ctru_present_bottom(const uint16_t *canvas, int width, int height);

#endif // SWIFT_3DS_SHIM_H
