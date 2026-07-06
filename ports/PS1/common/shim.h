// shim.h — declarations for ports/PS1/common/shim.c, imported into Swift via
// the psx_umbrella.h bridging header (PSn00bSDK's GPU/SPU/pad APIs are almost
// entirely C macros, which can't be imported into Swift directly — see every
// example in ~/Developer/swift-embedded-ps1 for the same pattern).

#include <stdint.h>

void ps1_init_heap(void);

extern uint32_t debug_last_alignment;
extern uint32_t debug_last_size;
extern uint32_t debug_last_result_isnull;

// Render context: double-buffered DISPENV/DRAWENV + ordering table + FntSort
// debug-font text (see swift-embedded-ps1's HelloPS1/shim.c reference).
void ps1_init_display(void);
void ps1_begin_frame(void);
void ps1_draw_text(int x, int y, const char *text);
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
