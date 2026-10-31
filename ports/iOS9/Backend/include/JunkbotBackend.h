#ifndef JUNKBOT_BACKEND_H
#define JUNKBOT_BACKEND_H

// The UIKit, SpriteKit and AVFoundation calls the iOS 9 port makes, in C so
// that Embedded Swift (compiled for the bare-metal armv7-apple-none-macho
// target) can call them.
//
// Bare-metal and iOS armv7 don't agree on how floating-point values, 64-bit
// integers and structs are passed, so only pointers and longs cross this
// boundary: a float goes as its bit pattern in an unsigned long, and values
// come back through pointers. Objects are retained pointers, released with
// jb_release.

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Objects

void jb_retain(void *object);
void jb_release(void *object);

// MARK: - App

/// Runs UIApplicationMain. Once the app has launched, `launched` gets the
/// SKView filling its landscape-only window.
int jb_main(void (*launched)(void *view));

/// Opens `url` in Safari.
void jb_open_url(const char *url);

/// Writes `length` bytes to the system log.
void jb_log(const void *bytes, unsigned long length);

/// Nanoseconds since boot.
void jb_uptime_nanoseconds(unsigned long long *nanoseconds);

// MARK: - Files

long jb_file_exists(const char *path);
/// The app bundle's resource directory, as a malloc'd string to free with jb_free.
char *jb_resource_path(void);
/// The app's Documents directory, as a malloc'd string to free with jb_free.
char *jb_documents_path(void);
/// The file's contents as a malloc'd, NUL-terminated string, or NULL.
char *jb_file_read(const char *path, unsigned long *length);
long jb_file_write(const char *path, const void *bytes, unsigned long length);
void jb_free(void *pointer);

// MARK: - SKView

void jb_view_present_scene(void *view, void *scene);
void jb_view_set_ignores_sibling_order(void *view, long ignores);

// MARK: - SKScene

/// Scene events forward to these, with the scene's context (jb_scene_set_context).
typedef struct {
    void (*did_move)(void *context, void *view);
    void (*update)(void *context, const double *current_time);
    /// `phase` is 0 began, 1 moved, 2 ended, 3 cancelled; `touches` holds
    /// `count` UITouch pointers, valid for the call.
    void (*touches)(void *context, long phase, void *const *touches, long count, void *event);
} jb_scene_handlers;

void jb_scene_set_handlers(const jb_scene_handlers *handlers);
void *jb_scene_create(unsigned long width, unsigned long height);
void jb_scene_set_context(void *scene, void *context);
void jb_scene_set_background_color(void *scene, unsigned long red, unsigned long green,
                                   unsigned long blue, unsigned long alpha);
/// An SKSceneScaleMode.
void jb_scene_set_scale_mode(void *scene, long mode);

// MARK: - SKNode

void jb_node_add_child(void *node, void *child);
void jb_node_remove_from_parent(void *node);
void jb_node_set_position(void *node, unsigned long x, unsigned long y);
void jb_node_set_z_position(void *node, unsigned long z);
void jb_node_set_z_rotation(void *node, unsigned long radians);
void jb_node_set_alpha(void *node, unsigned long alpha);

// MARK: - SKSpriteNode

void *jb_sprite_create(void *texture, unsigned long width, unsigned long height);
void jb_sprite_set_color(void *sprite, unsigned long red, unsigned long green,
                         unsigned long blue, unsigned long alpha);
void jb_sprite_set_color_blend_factor(void *sprite, unsigned long factor);

// MARK: - SKShapeNode

void *jb_shape_create_rect(unsigned long x, unsigned long y, unsigned long width, unsigned long height);
void *jb_shape_create_path(void *path);
void jb_shape_set_fill_color(void *shape, unsigned long red, unsigned long green,
                             unsigned long blue, unsigned long alpha);
void jb_shape_set_stroke_color(void *shape, unsigned long red, unsigned long green,
                               unsigned long blue, unsigned long alpha);
void jb_shape_set_line_width(void *shape, unsigned long width);

// MARK: - CGMutablePath

void *jb_path_create(void);
void jb_path_move(void *path, unsigned long x, unsigned long y);
void jb_path_add_line(void *path, unsigned long x, unsigned long y);
void jb_path_close(void *path);

// MARK: - SKTexture and UIImage

void *jb_image_create(const char *path);
void *jb_texture_create(void *image);
/// A texture showing `rect` (unit coordinates, origin bottom-left) of `texture`.
void *jb_texture_create_rect(void *texture, unsigned long x, unsigned long y,
                             unsigned long width, unsigned long height);
void jb_texture_size(void *texture, float *size);
/// An SKTextureFilteringMode.
void jb_texture_set_filtering_mode(void *texture, long mode);

// MARK: - UITouch

void jb_touch_location(void *touch, void *node, float *point);

// MARK: - Game controllers

/// Buttons reported to jb_gamepad_start's handler.
enum {
    JB_GAMEPAD_A = 0,
    /// The controller's pause button.
    JB_GAMEPAD_MENU = 1,
    JB_GAMEPAD_UP = 2,
    JB_GAMEPAD_DOWN = 3,
    JB_GAMEPAD_LEFT = 4,
    JB_GAMEPAD_RIGHT = 5,
};

/// Follows the most recently connected MFi controller, calling `button` on
/// the main thread when one of its buttons is pressed or released.
void jb_gamepad_start(void (*button)(long button, long pressed));
/// The controller's left thumbstick, x and y from -1 to 1 with +y up, or 0
/// (and zeros) without a controller that has one.
long jb_gamepad_left_stick(float *axes);

// MARK: - Audio

/// The file's contents, for playing with jb_audio_play, or NULL.
void *jb_audio_load(const char *path);
/// Starts playing `audio`, returning its AVAudioPlayer. The player is kept
/// alive until it finishes, so the result can be released right away.
void *jb_audio_play(void *audio);
long jb_audio_is_playing(void *player);
void jb_audio_stop(void *player);

#ifdef __cplusplus
}
#endif

#endif
