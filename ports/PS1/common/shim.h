// shim.h — declarations for ports/PS1/common/shim.c, imported into Swift via
// the psx_umbrella.h bridging header (PSn00bSDK's GPU/SPU/pad APIs are almost
// entirely C macros, which can't be imported into Swift directly — see every
// example in ~/Developer/swift-embedded-ps1 for the same pattern).

#include <stdint.h>

void ps1_init_heap(void);

// Render context: double-buffered DISPENV/DRAWENV + ordering table + FntSort
// debug-font text (see swift-embedded-ps1's HelloPS1/shim.c reference).
void ps1_init_display(void);
void ps1_begin_frame(void);
void ps1_draw_text(int x, int y, const char *text);
void ps1_flip(void);
