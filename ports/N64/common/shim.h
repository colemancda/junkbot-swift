//---------------------------------------------------------------------------------
// shim.h -- shared C support for the Junkbot N64 port.
//
// Every function here is a thin wrapper around libdragon (display/rdpq, the
// joypad subsystem, the low-level audio API, debug printf) compiled by the
// libdragon mips64-elf GCC, so it can see libdragon's headers directly --
// Swift never does (see n64_umbrella.h). Two hard ABI rules shape every
// signature below:
//
//   - <=4 register arguments, no stack arguments (libdragon is o64, the
//     Embedded Swift MIPS object is o32 -- see build.sh).
//   - no float/double crosses this boundary at all.
//
// Consequently every "give Swift a subsystem" call (framebuffer, audio
// buffer, input) hands back a raw pointer + plain integers ONCE per frame;
// all the actual per-pixel/per-sample/per-button work happens in Swift on
// that pointer, not through further bridge calls (see source/Renderer.swift,
// source/Audio.swift).
//---------------------------------------------------------------------------------
#ifndef SWIFT_N64_SHIM_H
#define SWIFT_N64_SHIM_H

#include <stdint.h>

// One-time init: joypad, display (320x240x16bpp double-buffered), rdpq, the
// low-level audio API, and debug_init_isviewer() (routes printf to the
// emulator's IS-Viewer / -Wl,--wrap dumps on hardware).
void n64_init(void);

// --- Video -----------------------------------------------------------------

// Blocks (like display_get()) until a display buffer is free, attaches it via
// rdpq, and returns its pixel buffer as a plain integer address (N64 pointers
// fit in 32 bits) plus width/height/stride-in-pixels via out-params. The
// buffer is the display's native 16bpp format (5551: RRRRR GGGGG BBBBB A),
// row-major -- see source/Renderer.swift's `packRGBA5551`.
uint32_t n64_display_attach(int32_t *width, int32_t *height, int32_t *strideBytes);

// rdpq_detach_show(): presents the buffer returned by the matching
// n64_display_attach and returns to the vsync queue.
void n64_display_show(void);

// --- Input -------------------------------------------------------------------

// joypad_poll() plus joypad_get_buttons_held(JOYPAD_PORT_1).raw as the low 16
// bits (0 elsewhere). Button bit layout is the REVERSE of libdragon's
// joypad_buttons_t declaration order: this big-endian MIPS target's GCC packs
// the first-declared bitfield member into the MOST significant bit (confirmed
// empirically -- source/main.swift's BTN_* constants have the full story):
// bit15=A bit14=B bit13=Z bit12=Start bit11=D_up bit10=D_down bit9=D_left
// bit8=D_right bit7=Y bit6=X bit5=L bit4=R bit3=C_up bit2=C_down
// bit1=C_left bit0=C_right. Call once per frame before the pressed/released
// variants (those read the same already-polled snapshot).
uint32_t n64_buttons_held(void);
uint32_t n64_buttons_pressed(void);
uint32_t n64_buttons_released(void);

// Analog stick position, port 1, range roughly (-85,+85) on OEM hardware
// (JOYPAD_RANGE_N64_STICK_MAX = 90). Two out-params instead of a packed
// return so each half keeps its sign without a shift/mask dance in Swift.
void n64_stick(int32_t *x, int32_t *y);

// --- Audio -------------------------------------------------------------------

// audio_get_buffer_length(): stereo sample capacity of one internal buffer
// (multiply by 4 for bytes: 2 channels * sizeof(int16_t)).
int32_t n64_audio_buffer_length(void);

// audio_can_write(): nonzero if n64_audio_begin will not block.
int32_t n64_audio_can_write(void);

// Blocks until a buffer is free (audio_write_begin) and returns it as a plain
// integer address; holds exactly n64_audio_buffer_length() stereo (LR
// interleaved) 16-bit samples. Call n64_audio_end() once Swift has filled it.
uint32_t n64_audio_begin(void);
void n64_audio_end(void);

// --- Debug print (IS-Viewer / hardware serial via libdragon's debug.h) -----

void n64_puts(const char *s);
void n64_printf_1i(const char *fmt, int32_t a);
void n64_printf_2i(const char *fmt, int32_t a, int32_t b);
// printf("%.*s", len, s): a non-NUL-terminated run of bytes (Swift StaticString
// / String UTF-8 buffers).
void n64_print_len(const char *s, int32_t len);

#endif // SWIFT_N64_SHIM_H
