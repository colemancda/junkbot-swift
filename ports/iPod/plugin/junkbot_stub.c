/***************************************************************************
 *
 * junkbot_stub.c -- SIMULATOR-only stand-ins for the Embedded Swift entry
 * points, so the C scaffolding (loop, click-wheel input, blit, intro/status,
 * pause menu) can be exercised in the Rockbox UI simulator on the host, where
 * the armv4t libjunkbot.a can't link. The stub has no real engine: it draws a
 * moving test pattern with a cursor, and fakes a tiny level list so the intro /
 * navigation / win-lose flow can be walked through.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 ****************************************************************************/

#include "plugin.h"

#define GAME_W 176
#define GAME_H 120

static unsigned short *fb;
static unsigned frame_no;
static int level;
static int moves;
static int grabbing;
static int cursor_x = GAME_W / 2, cursor_y = GAME_H / 2;

int junkbot_shim_init(void) { return 0; }

int junkbot_init(unsigned short *canvas, const void *sprites, int sprites_bytes,
                 const void *levels, int levels_bytes)
{
    (void)sprites;
    (void)sprites_bytes;
    (void)levels;
    (void)levels_bytes;
    fb = canvas;
    return 0;
}

int junkbot_level_count(void) { return 3; }
int junkbot_current_level(void) { return level; }
void junkbot_load_level(int index) { level = index; moves = 0; }
void junkbot_next_level(void) { if (level + 1 < 3) level++; moves = 0; }
void junkbot_prev_level(void) { if (level > 0) level--; moves = 0; }
void junkbot_restart(void) { moves = 0; }

void junkbot_move_cursor(int dx, int dy)
{
    cursor_x += dx * 15;
    cursor_y += dy * 18;
    if (cursor_x < 4) cursor_x = 4;
    if (cursor_x > GAME_W - 4) cursor_x = GAME_W - 4;
    if (cursor_y < 4) cursor_y = 4;
    if (cursor_y > GAME_H - 4) cursor_y = GAME_H - 4;
    if (grabbing) moves++;
}

void junkbot_toggle_grab(void) { grabbing = !grabbing; }
int junkbot_is_grabbing(void) { return grabbing; }

int junkbot_tick(int elapsed_ticks)
{
    (void)elapsed_ticks;
    frame_no++;
    return 0; /* never resolves -- the stub level is unwinnable on purpose */
}

int junkbot_winlose(void) { return 0; }
int junkbot_moves(void) { return moves; }
const char *junkbot_level_title(void) { return "Test Pattern"; }
const char *junkbot_level_hint(void)
{
    return "Simulator stub -- the real engine is the armv4t libjunkbot.a. "
           "Move the click wheel, SELECT toggles the cursor color.";
}

void junkbot_render(void)
{
    int x, y;

    if (fb == NULL)
        return;

    for (y = 0; y < GAME_H; y++)
        for (x = 0; x < GAME_W; x++)
            fb[y * GAME_W + x] = (unsigned short)
                ((((x + frame_no) & 0x1f) << 11) | (((y + frame_no) & 0x3f) << 5));

    for (y = cursor_y - 6; y <= cursor_y + 6; y++)
        for (x = cursor_x - 6; x <= cursor_x + 6; x++)
            if (x >= 0 && x < GAME_W && y >= 0 && y < GAME_H &&
                (x == cursor_x - 6 || x == cursor_x + 6 ||
                 y == cursor_y - 6 || y == cursor_y + 6))
                fb[y * GAME_W + x] = grabbing ? 0x07ff : 0xffe0;
}
