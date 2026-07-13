/***************************************************************************
 *
 * Junkbot for Rockbox (iPod Nano 2G and other click-wheel, >=176x132 RGB565
 * targets) -- C host for the Embedded Swift engine in libjunkbot.a (built from
 * junkbot-swift's JunkbotCore by ports/iPod/Makefile).
 *
 * This file owns everything Rockbox-shaped: the loop, click-wheel input, the
 * scrolled world blit, the level intro / win-lose prompts, the status strip,
 * pause/quit. The Swift side (junkbot_init/tick/render/... in source/Plugin.swift)
 * owns the game state: the engine, the current level, a click-wheel cursor, and
 * the scrolled viewport. See ports/iPod/README.md.
 *
 * ASSETS ON THE FILESYSTEM: sprites.bin (~5.6MB of RGB555 pixel data) is far
 * too big to link into a plugin, so -- unlike every other Junkbot port -- it is
 * NOT embedded. It is installed to /.rockbox/junkbot/sprites.bin and loaded into
 * the audio buffer here at startup; its pointer is handed to junkbot_init.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 ****************************************************************************/

#include "plugin.h"

/* Embedded Swift entry points (libjunkbot.a; see source/Plugin.swift). The
 * simulator build substitutes junkbot_stub.c for all of these. */
extern int junkbot_init(unsigned short *canvas, const void *sprites, int sprites_bytes);
extern int junkbot_level_count(void);
extern int junkbot_current_level(void);
extern void junkbot_load_level(int index);
extern void junkbot_next_level(void);
extern void junkbot_prev_level(void);
extern void junkbot_restart(void);
extern void junkbot_move_cursor(int dx, int dy);
extern void junkbot_toggle_grab(void);
extern int junkbot_is_grabbing(void);
extern int junkbot_tick(int elapsed_ticks);
extern void junkbot_render(void);
extern int junkbot_winlose(void);
extern int junkbot_moves(void);
extern const char *junkbot_level_title(void);
extern const char *junkbot_level_hint(void);
/* rockbox_shim.c (or junkbot_stub.c on sim): TLSF allocator arena setup. */
extern int junkbot_shim_init(void);

#define SPRITES_PATH ROCKBOX_DIR "/junkbot/sprites.bin"

/* Game canvas: the Swift renderer rasterizes 176x120 RGB565 here; a 12px status
 * strip sits above it. Must match source/Renderer.swift's screenWidth/height. */
#define GAME_W 176
#define GAME_H 120
#define STATUS_H 12
#define GAME_X ((LCD_WIDTH - GAME_W) / 2)
#define GAME_Y STATUS_H

static fb_data canvas[GAME_W * GAME_H];

/* ------------------------------------------------------------------------ */
/* Asset load: sprites.bin -> audio buffer (best-effort; a missing file is a  */
/* hard error since nothing can be drawn without it).                         */
/* ------------------------------------------------------------------------ */
static int load_sprites(const void **out, int *out_bytes)
{
    int fd = rb->open(SPRITES_PATH, O_RDONLY);
    size_t need, have;
    void *buf;

    if (fd < 0)
        return -1;
    need = (size_t)rb->filesize(fd);
    buf = rb->plugin_get_audio_buffer(&have);
    if (buf == NULL || have < need || rb->read(fd, buf, need) != (ssize_t)need) {
        rb->close(fd);
        return -1;
    }
    rb->close(fd);
    *out = buf;
    *out_bytes = (int)need;
    return 0;
}

/* ------------------------------------------------------------------------ */
/* Text helpers (Rockbox's own font -- no glyph asset needed).               */
/* ------------------------------------------------------------------------ */
static void draw_status(void)
{
    char buf[48];
    int total = junkbot_level_count();

    rb->lcd_set_foreground(LCD_BLACK);
    rb->lcd_fillrect(0, 0, LCD_WIDTH, STATUS_H);
    rb->lcd_set_foreground(LCD_WHITE);
    rb->snprintf(buf, sizeof(buf), "Lvl %d/%d  Moves %d",
                 junkbot_current_level() + 1, total, junkbot_moves());
    rb->lcd_putsxy(2, 1, buf);
}

/* Draws `text` word-wrapped within [x, x+maxw), starting at y; returns the y
 * just below the last line. Uses the current font's real glyph metrics. */
static int draw_wrapped(const char *text, int x, int y, int maxw)
{
    int space_w, line_h, dummy;
    char word[64];
    int pen_x = x, pen_y = y;

    rb->lcd_getstringsize(" ", &space_w, &line_h);

    while (*text) {
        int n = 0, ww;
        while (*text == ' ')
            text++;
        while (text[n] && text[n] != ' ' && n < (int)sizeof(word) - 1) {
            word[n] = text[n];
            n++;
        }
        if (n == 0)
            break;
        word[n] = '\0';
        text += n;

        rb->lcd_getstringsize(word, &ww, &dummy);
        if (pen_x > x && pen_x + ww > x + maxw) {
            pen_x = x;
            pen_y += line_h;
        }
        rb->lcd_putsxy(pen_x, pen_y, word);
        pen_x += ww + space_w;
    }
    return pen_y + line_h;
}

/* Full-screen level intro: title + hint + controls. Returns:
 *   1 start   0 quit   -1 usb   2 prev level   3 next level */
static int show_intro(void)
{
    int y;

    rb->lcd_set_background(LCD_BLACK);
    rb->lcd_set_foreground(LCD_WHITE);
    rb->lcd_clear_display();

    {
        char head[32];
        rb->snprintf(head, sizeof(head), "LEVEL %d/%d",
                     junkbot_current_level() + 1, junkbot_level_count());
        rb->lcd_putsxy(2, 2, head);
    }
    y = draw_wrapped(junkbot_level_title(), 2, 16, LCD_WIDTH - 4);
    y = draw_wrapped(junkbot_level_hint(), 2, y + 4, LCD_WIDTH - 4);

    rb->lcd_putsxy(2, LCD_HEIGHT - 26, "SELECT: play");
    rb->lcd_putsxy(2, LCD_HEIGHT - 14, "L/R: change level");
    rb->lcd_update();

    for (;;) {
        long ev = rb->button_get(true);
        if (rb->default_event_handler(ev) == SYS_USB_CONNECTED)
            return -1;
        switch (ev) {
        case BUTTON_SELECT:
            return 1;
        case BUTTON_LEFT:
            junkbot_prev_level();
            return 2;
        case BUTTON_RIGHT:
            junkbot_next_level();
            return 3;
        case BUTTON_MENU:
            return 0;
        default:
            break;
        }
    }
}

/* Win/lose banner over the frozen board. Returns when any key is pressed. */
static void show_outcome(int outcome)
{
    const char *msg = outcome == 1 ? " YOU WIN! " : " TRY AGAIN ";
    int w, h;

    rb->lcd_getstringsize(msg, &w, &h);
    rb->lcd_set_foreground(LCD_WHITE);
    rb->lcd_fillrect((LCD_WIDTH - w) / 2 - 4, LCD_HEIGHT / 2 - h, w + 8, h * 2 + 4);
    rb->lcd_set_foreground(LCD_BLACK);
    rb->lcd_putsxy((LCD_WIDTH - w) / 2, LCD_HEIGHT / 2 - h + 2, msg);
    {
        int w2, h2;
        const char *sub = "press any key";
        rb->lcd_getstringsize(sub, &w2, &h2);
        rb->lcd_putsxy((LCD_WIDTH - w2) / 2, LCD_HEIGHT / 2 + 2, sub);
    }
    rb->lcd_update();
}

/* HOLD pause menu. Returns: 0 resume  1 quit  -1 usb. Restart/next/prev act in
 * place (reloading the level) and then resume. */
static int pause_menu(bool *reintro)
{
    MENUITEM_STRINGLIST(menu, "Junkbot", NULL,
                        "Resume", "Restart level", "Next level",
                        "Previous level", "Quit");
#ifdef HAS_BUTTON_HOLD
    if (rb->button_hold()) {
        rb->splash(0, "Paused -- slide HOLD off");
        while (rb->button_hold())
            rb->sleep(HZ / 10);
    }
#endif
    switch (rb->do_menu(&menu, NULL, NULL, false)) {
    case 1: junkbot_restart();    *reintro = true; break;
    case 2: junkbot_next_level(); *reintro = true; break;
    case 3: junkbot_prev_level(); *reintro = true; break;
    case 4: return 1;
    default: break;
    }
    rb->lcd_clear_display();
    rb->lcd_update();
    return 0;
}

/* One frame's input. Fills *usb / *pause, forwards cursor + grab to Swift. */
static void handle_input(bool *usb, bool *pause)
{
    long ev;
    while ((ev = rb->button_get(false)) != BUTTON_NONE) {
        if (rb->default_event_handler(ev) == SYS_USB_CONNECTED) {
            *usb = true;
            return;
        }
        switch (ev & ~BUTTON_REPEAT) {
        case BUTTON_SCROLL_FWD: junkbot_move_cursor(1, 0);  break;
        case BUTTON_SCROLL_BACK:junkbot_move_cursor(-1, 0); break;
        case BUTTON_LEFT:       junkbot_move_cursor(-1, 0); break;
        case BUTTON_RIGHT:      junkbot_move_cursor(1, 0);  break;
        case BUTTON_MENU:       junkbot_move_cursor(0, -1); break;
        case BUTTON_PLAY:       junkbot_move_cursor(0, 1);  break;
        case BUTTON_SELECT:
            if (!(ev & BUTTON_REPEAT))
                junkbot_toggle_grab();
            break;
        default:
            break;
        }
    }
#ifdef HAS_BUTTON_HOLD
    *pause = rb->button_hold();
#else
    (void)pause;
#endif
}

/* Plays the current level until it resolves. Returns:
 *   0 quit   1 win   2 lose   -1 usb   4 reintro (level changed via pause). */
static int play_level(void)
{
    long last = *rb->current_tick;

    junkbot_move_cursor(0, 0); /* prime hover/scroll without moving */

    for (;;) {
        bool usb = false, pause = false;
        long now;
        int outcome;

        handle_input(&usb, &pause);
        if (usb)
            return -1;
        if (pause) {
            bool reintro = false;
            int r = pause_menu(&reintro);
            if (r == 1)
                return 0;
            last = *rb->current_tick;
            if (reintro)
                return 4;
        }

        now = *rb->current_tick;
        outcome = junkbot_tick((int)(now - last));
        last = now;

        junkbot_render();
        rb->lcd_bitmap(canvas, GAME_X, GAME_Y, GAME_W, GAME_H);
        draw_status();
        rb->lcd_update();

        if (outcome != 0) {
            show_outcome(outcome);
            /* Wait for a key to acknowledge. */
            long ack;
            do {
                ack = rb->button_get(true);
                if (rb->default_event_handler(ack) == SYS_USB_CONNECTED)
                    return -1;
            } while (!(ack & (BUTTON_SELECT | BUTTON_MENU | BUTTON_PLAY |
                              BUTTON_LEFT | BUTTON_RIGHT)));
            return outcome;
        }

        rb->sleep(HZ / 33); /* ~33fps input/render cap; sim paces itself */
    }
}

enum plugin_status plugin_start(const void *parameter)
{
    enum plugin_status status = PLUGIN_OK;
    const void *sprites = NULL;
    int sprites_bytes = 0;
    bool running = true;

    (void)parameter;

    if (junkbot_shim_init() != 0) {
        rb->splash(HZ * 2, "junkbot: allocator init failed");
        return PLUGIN_ERROR;
    }
    if (load_sprites(&sprites, &sprites_bytes) != 0) {
        rb->splash(HZ * 3, "junkbot: cannot load " SPRITES_PATH);
        return PLUGIN_ERROR;
    }

#ifdef HAVE_ADJUSTABLE_CPU_FREQ
    rb->cpu_boost(true);
#endif

    if (junkbot_init(canvas, sprites, sprites_bytes) != 0) {
        rb->splash(HZ * 2, "junkbot: engine init failed");
        status = PLUGIN_ERROR;
        goto out;
    }

    while (running) {
        int intro = show_intro();
        int result;

        if (intro == -1) { status = PLUGIN_USB_CONNECTED; break; }
        if (intro == 0) break;             /* quit from intro */
        if (intro == 2 || intro == 3)      /* level changed; show its intro */
            continue;

        result = play_level();
        switch (result) {
        case -1: status = PLUGIN_USB_CONNECTED; running = false; break;
        case 0:  running = false; break;   /* quit */
        case 1:  junkbot_next_level(); break; /* win -> advance */
        case 2:  junkbot_restart();    break; /* lose -> retry */
        case 4:  break;                    /* pause changed level -> reintro */
        default: break;
        }
    }

out:
#ifdef HAVE_ADJUSTABLE_CPU_FREQ
    rb->cpu_boost(false);
#endif
    return status;
}
