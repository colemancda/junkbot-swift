//---------------------------------------------------------------------------------
// shim.c -- shared C support for the Junkbot N64 port (see shim.h).
//---------------------------------------------------------------------------------
#include <libdragon.h>
#include <errno.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "shim.h"

static surface_t *s_attached = NULL;

void n64_init(void) {
	debug_init_isviewer();
	joypad_init();
	display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, FILTERS_RESAMPLE);
	rdpq_init();
	audio_init(22050, 4);
}

// --- Video -------------------------------------------------------------------

uint32_t n64_display_attach(int32_t *width, int32_t *height, int32_t *strideBytes) {
	s_attached = display_get();
	rdpq_attach(s_attached, NULL);
	*width = s_attached->width;
	*height = s_attached->height;
	*strideBytes = s_attached->stride;
	return (uint32_t)(uintptr_t)s_attached->buffer;
}

void n64_display_show(void) {
	rdpq_detach_show();
	s_attached = NULL;
}

// --- Input -------------------------------------------------------------------

uint32_t n64_buttons_held(void) {
	joypad_poll();
	return joypad_get_buttons_held(JOYPAD_PORT_1).raw;
}

uint32_t n64_buttons_pressed(void) {
	return joypad_get_buttons_pressed(JOYPAD_PORT_1).raw;
}

uint32_t n64_buttons_released(void) {
	return joypad_get_buttons_released(JOYPAD_PORT_1).raw;
}

void n64_stick(int32_t *x, int32_t *y) {
	joypad_inputs_t in = joypad_get_inputs(JOYPAD_PORT_1);
	*x = in.stick_x;
	*y = in.stick_y;
}

// --- Audio ---------------------------------------------------------------------

int32_t n64_audio_buffer_length(void) {
	return audio_get_buffer_length();
}

int32_t n64_audio_can_write(void) {
	return audio_can_write();
}

uint32_t n64_audio_begin(void) {
	return (uint32_t)(uintptr_t)audio_write_begin();
}

void n64_audio_end(void) {
	audio_write_end();
}

// --- Debug print -----------------------------------------------------------

void n64_puts(const char *s) {
	printf("%s", s);
}

void n64_printf_1i(const char *fmt, int32_t a) {
	printf(fmt, a);
}

void n64_printf_2i(const char *fmt, int32_t a, int32_t b) {
	printf(fmt, a, b);
}

void n64_print_len(const char *s, int32_t len) {
	printf("%.*s", (int)len, s);
}

//---------------------------------------------------------------------------------
// Runtime support the Embedded Swift object needs but libdragon's newlib does
// not provide for this target (same gaps ports/3DS's and ports/NDS's shim.c
// work around, plus the stack-protector globals the swift-embedded-nintendo-64
// reference's swift_stubs.c needs for this target).
//---------------------------------------------------------------------------------

void *__stack_chk_guard = (void *)0xdeadbeef;

void __stack_chk_fail(void) {
	abort();
}

// Swift's allocator calls posix_memalign; libdragon's newlib only ships memalign.
int posix_memalign(void **memptr, size_t alignment, size_t size) {
	void *p = memalign(alignment, size);
	if (!p) return ENOMEM;
	*memptr = p;
	return 0;
}

// Embedded Swift's runtime can reference arc4random_buf (e.g. Array.randomElement(),
// used for music-group/track selection); the N64 has no entropy source, so supply
// a small xorshift PRNG. NOT cryptographically secure -- nothing in this port
// relies on randomness for anything security-sensitive.
void arc4random_buf(void *buf, size_t n) {
	static uint32_t s = 0x2545F491u;
	uint8_t *p = (uint8_t *)buf;
	for (size_t i = 0; i < n; i++) {
		s ^= s << 13;
		s ^= s >> 17;
		s ^= s << 5;
		p[i] = (uint8_t)s;
	}
}
