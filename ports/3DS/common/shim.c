//---------------------------------------------------------------------------------
// shim.c -- shared C support for the Junkbot 3DS port (see shim.h).
//---------------------------------------------------------------------------------
#include <3ds.h>
#include <errno.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "shim.h"
#include "assets.h"

//---------------------------------------------------------------------------------
// Runtime support the Embedded Swift object needs but devkitARM's newlib does
// not provide for this target.
//---------------------------------------------------------------------------------

// Swift's allocator calls posix_memalign; newlib's armv6k/fpu libc only ships
// memalign (declared, but never defined -- same gap ports/NDS's shim works
// around).
int posix_memalign(void **memptr, size_t alignment, size_t size) {
	void *p = memalign(alignment, size);
	if (!p) return ENOMEM;
	*memptr = p;
	return 0;
}

// Embedded Swift's runtime can reference arc4random_buf (e.g. for the system
// RNG); newlib's arc4random_buf is implemented but falls through to
// getentropy for seeding, which libctru doesn't implement. Supply a small
// xorshift PRNG as the missing entropy source instead. NOT cryptographically
// secure -- fine here, since nothing in this port relies on randomness for
// anything security-sensitive (only `Array.randomElement()` for music picks).
static uint32_t s_entropyState = 0x2545F491u;

int getentropy(void *buf, size_t buflen) {
	uint8_t *p = (uint8_t *)buf;
	for (size_t i = 0; i < buflen; i++) {
		s_entropyState ^= s_entropyState << 13;
		s_entropyState ^= s_entropyState >> 17;
		s_entropyState ^= s_entropyState << 5;
		p[i] = (uint8_t)s_entropyState;
	}
	return 0;
}

// Some newlib configurations call the reentrant form directly rather than
// through the `_getentropy_r` macro in <reent.h> (which just expands to
// `getentropy`); the first parameter is an unused `struct _reent *`, but its
// exact type doesn't matter for C's un-mangled linkage.
int _getentropy_r(void *reent, void *buf, size_t buflen) {
	(void)reent;
	return getentropy(buf, buflen);
}

void ctru_puts(const char *s) {
	printf("%s", s);
}

void ctru_printf_1i(const char *fmt, int a) {
	printf(fmt, a);
}

void ctru_printf_2i(const char *fmt, int a, int b) {
	printf(fmt, a, b);
}

void ctru_print_len(const char *s, int len) {
	printf("%.*s", len, s);
}

//---------------------------------------------------------------------------------
// Audio (NDSP) -- see shim.h. audio.bin/music.bin are embedded read-only in the
// ELF's .rodata (bin2s), but NDSP's DMA needs its source in "linear" memory, so
// both blobs are copied once (at ctru_audio_init) into linearAlloc'd buffers;
// playback just points wave buffers at offsets into those persistent copies --
// no per-play allocation.
//---------------------------------------------------------------------------------
static int16_t *linearAudioPCM = NULL;
static int16_t *linearMusicPCM = NULL;

// One NDSP channel (see source/Audio.swift for channel assignment) needs one
// ndspWaveBuf that stays alive for as long as that channel might be playing;
// Embedded Swift can't touch this tagged-union struct directly (see shim.h),
// so every channel's wave buffer lives here instead.
#define CTRU_NDSP_CHANNEL_COUNT 24
static ndspWaveBuf channelWaveBuf[CTRU_NDSP_CHANNEL_COUNT];

void ctru_audio_init(void) {
	ndspInit();
	ndspSetOutputMode(NDSP_OUTPUT_STEREO);
	ndspSetMasterVol(1.0f);

	uint32_t audioLen = ctru_asset_audio_bin_size();
	linearAudioPCM = (int16_t *)linearAlloc(audioLen);
	memcpy(linearAudioPCM, ctru_asset_audio_bin(), audioLen);
	DSP_FlushDataCache(linearAudioPCM, audioLen);

	uint32_t musicLen = ctru_asset_music_bin_size();
	linearMusicPCM = (int16_t *)linearAlloc(musicLen);
	memcpy(linearMusicPCM, ctru_asset_music_bin(), musicLen);
	DSP_FlushDataCache(linearMusicPCM, musicLen);
}

void ctru_play_pcm16(int channel, int bank, unsigned sampleOffset, unsigned sampleCount,
                      float rate, int loop) {
	if (channel < 0 || channel >= CTRU_NDSP_CHANNEL_COUNT || sampleCount == 0) return;

	int16_t *base = bank == 0 ? linearAudioPCM : linearMusicPCM;

	ndspChnReset(channel);
	ndspChnSetInterp(channel, NDSP_INTERP_LINEAR);
	ndspChnSetRate(channel, rate);
	ndspChnSetFormat(channel, NDSP_FORMAT_MONO_PCM16);

	float mix[12] = {0};
	mix[0] = 1.0f;  // left
	mix[1] = 1.0f;  // right
	ndspChnSetMix(channel, mix);

	ndspWaveBuf *buf = &channelWaveBuf[channel];
	memset(buf, 0, sizeof(*buf));
	buf->data_pcm16 = base + sampleOffset;
	buf->nsamples = sampleCount;
	buf->looping = loop ? true : false;
	ndspChnWaveBufAdd(channel, buf);
}

void ctru_stop_channel(int channel) {
	if (channel < 0 || channel >= CTRU_NDSP_CHANNEL_COUNT) return;
	ndspChnWaveBufClear(channel);
	ndspChnReset(channel);
}

//---------------------------------------------------------------------------------
// Bottom-screen present -- see shim.h's module doc for why this transposes.
//---------------------------------------------------------------------------------
void ctru_present_bottom(const uint16_t *canvas, int width, int height) {
	u16 fbWidth = 0, fbHeight = 0;
	uint16_t *fb = (uint16_t *)gfxGetFramebuffer(GFX_BOTTOM, GFX_LEFT, &fbWidth, &fbHeight);
	if (!fb) return;

	// fbWidth/fbHeight are the *physical* (portrait) dimensions -- fbWidth is
	// our canvas's height and vice versa. Pixel (x,y) in our landscape canvas
	// lands at column x, row (height-1-y) of the column-major hardware buffer.
	for (int y = 0; y < height; y++) {
		const uint16_t *srcRow = canvas + y * width;
		int dstRow = height - 1 - y;
		for (int x = 0; x < width; x++) {
			fb[x * height + dstRow] = srcRow[x];
		}
	}

	gfxFlushBuffers();
	gfxSwapBuffers();
}
