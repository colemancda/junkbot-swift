#ifndef JUNKBOT_CORE_BRIDGE_H
#define JUNKBOT_CORE_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    int32_t id;
    int32_t type;
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
    
    int32_t facing;
    int32_t facingY;
    int32_t animationFrame;
    
    int32_t widthInStuds;
    int32_t colorIndex;
    
    bool grabbed;
    bool fixed;
    bool removeBeforeRender;
    
    bool armored;
    bool losingShield;
    bool gettingShield;
    bool dead;
    bool collectingBin;
    bool headLoaded;
    
    bool scaredy;
    bool on;
    bool used;
    bool blocked;
    bool active;
    bool splashing;
    
    int32_t switchID;
    int32_t teleportID;
    
    int32_t grabOffsetX;
    int32_t grabOffsetY;
} JunkbotEntityState;

typedef struct {
    void (*drawEntity)(JunkbotEntityState* state);
    void (*drawWindEffect)(int32_t x, int32_t y, int32_t extent);
    void (*drawLaserBeam)(int32_t x, int32_t y, int32_t extent, int32_t facing);
    void (*drawTeleportEffect)(int32_t x, int32_t y, int32_t frame);
    void (*playSound)(int32_t soundID);
} JunkbotRenderCallbacks;

void core_init(void);
void core_tick(void);
void core_set_render_callbacks(JunkbotRenderCallbacks callbacks);

void core_begin_load_level(int32_t boundsX, int32_t boundsY, int32_t boundsW, int32_t boundsH);
void core_add_brick(int32_t x, int32_t y, int32_t widthInStuds, int32_t colorIndex, int32_t fixed);
void core_add_junkbot(int32_t x, int32_t y, int32_t facing, int32_t armored);
void core_add_gearbot(int32_t x, int32_t y, int32_t facing);
void core_add_climbbot(int32_t x, int32_t y, int32_t facing, int32_t facingY);
void core_add_flybot(int32_t x, int32_t y, int32_t facing);
void core_add_eyebot(int32_t x, int32_t y, int32_t facing, int32_t facingY);
void core_add_bin(int32_t x, int32_t y, int32_t facing, int32_t scaredy);
void core_add_crate(int32_t x, int32_t y);
void core_add_fire(int32_t x, int32_t y, int32_t on, int32_t switchID);
void core_add_fan(int32_t x, int32_t y, int32_t on, int32_t switchID);
void core_add_switch(int32_t x, int32_t y, int32_t on, int32_t switchID);
void core_add_pipe(int32_t x, int32_t y);
void core_add_shield(int32_t x, int32_t y, int32_t used, int32_t fixed);
void core_add_jump(int32_t x, int32_t y, int32_t fixed);
void core_add_teleport(int32_t x, int32_t y, int32_t teleportID);
void core_add_laser(int32_t x, int32_t y, int32_t facing, int32_t on, int32_t switchID);
void core_finish_load_level(void);

void core_mouse_down(int32_t x, int32_t y);
void core_mouse_move(int32_t x, int32_t y);
void core_mouse_up(int32_t x, int32_t y);
void core_set_paused(bool paused);
void core_set_viewport(int32_t cx, int32_t cy, float scale);
void core_set_rng_seed(uint32_t seed);

int32_t core_get_win_lose_state(void);
void core_get_viewport(int32_t *cx, int32_t *cy, float *scale);

#endif
