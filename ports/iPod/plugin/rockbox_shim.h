/*
 * rockbox_shim.h -- the C surface JunkbotCore's Embedded Swift sees on Rockbox.
 *
 * This header is parsed twice, by two different compilers:
 *   1. swiftc's Clang importer (via module.modulemap, as the `CRockbox` module,
 *      -ffreestanding, armv4t-none-none-eabi) when compiling the engine, and
 *   2. arm-elf-eabi-gcc when compiling rockbox_shim.c inside the Rockbox tree.
 * So it must stay self-contained: no plugin.h, no libc headers beyond what a
 * freestanding compiler provides. Mirrors the role ctru_umbrella.h/assets.h play
 * for ports/3DS, minus libctru (the iPod side keeps all hardware access in C).
 */
#ifndef JUNKBOT_ROCKBOX_SHIM_H
#define JUNKBOT_ROCKBOX_SHIM_H

/* libm gaps: Rockbox has no libm, so rockbox_shim.c carries small soft-float
 * implementations. The engine's cosmetic math (RenderList scaredy-bin wobble)
 * only calls sinf/floorf/fmodf; the rest are declared for completeness. */
float sinf(float x);
float cosf(float x);
float fmodf(float x, float y);
float floorf(float x);
float ceilf(float x);

/* Fire-and-forget sound effect trigger, called by Swift's onPlaySound with a
 * SoundID.rawValue. A no-op until the audio phase lands (see mixer.c / the audio
 * plan in ports/iPod/README.md); the C mixer behind it never runs Swift. */
void rb_audio_sfx(int id);

/* Fixed-arity debug print for Swift (Embedded Swift can't call varargs).
 * Splash-based; compiled out unless JUNKBOT_DEBUG. */
void rb_puts(const char *s);

#endif /* JUNKBOT_ROCKBOX_SHIM_H */
