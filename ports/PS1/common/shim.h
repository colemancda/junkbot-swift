// shim.h — declarations for ports/PS1/common/shim.c, imported into Swift via
// the psx_umbrella.h bridging header (PSn00bSDK's GPU/SPU/pad APIs are almost
// entirely C macros, which can't be imported into Swift directly — see every
// example in ~/Developer/swift-embedded-ps1 for the same pattern).

#include <stdint.h>

void ps1_init_heap(void);

// SIO-based logging: DuckStation's "Redirect SIO to TTY" debug option (or
// real hardware's serial port) surfaces this in a log window instead of
// needing to draw text to the screen and flip buffers (which costs 2 frame
// flips per debug line -- see ps1_draw_text/ps1_draw_int above). Routes
// through libpsxapi.a's puts, which calls this file's putchar -> AddSIO.
void ps1_log(const char *message);

// Render context: double-buffered DISPENV/DRAWENV + ordering table + FntSort
// debug-font text (see swift-embedded-ps1's HelloPS1/shim.c reference).
void ps1_init_display(void);
void ps1_begin_frame(void);
void ps1_draw_text(int x, int y, const char *text);
// Debug-only: draws "<label><decimal value>" via FntPrint (which, unlike
// ps1_draw_text/FntSort, supports printf-style formatting) -- used for
// bisecting hangs from Swift without needing any Swift-side string/array
// formatting code (itself a risk while debugging Array-growth bugs).
void ps1_draw_int(int x, int y, const char *label, int value);
void ps1_flip(void);

// World framebuffer: Swift software-rasterizes the game world into this RAM
// buffer (320x240 UInt16, native PS1 BGR555 with bit15=0 for opaque/no-blend
// -- see source/Renderer.swift), then ps1_present_world uploads it into the
// current draw buffer's VRAM region via LoadImage2 before the HUD text (drawn
// through the ordering table, see ps1_draw_text) and ps1_flip's DrawOTag/swap.
// Same "CPU-blit into a RAM buffer, hand the whole frame to the display in
// one shot" shape as ports/N64/source/Renderer.swift, adapted for PS1's VRAM
// (which the CPU can't address directly -- unlike N64's memory-mapped
// framebuffer, PS1 pixels only reach the screen via a GPU DMA transfer).
uint16_t *ps1_world_framebuffer(void);
void ps1_present_world(void);

const uint8_t *ps1_asset_sprites_bin_noninline(void);
