#import <UIKit/UIKit.h>
#import <SpriteKit/SpriteKit.h>
#import <AVFoundation/AVFoundation.h>
#import <GameController/GameController.h>
#include <mach/mach_time.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "JunkbotBackend.h"

static inline CGFloat jb_float(unsigned long bits) {
    union { unsigned int bits; float value; } u = { .bits = (unsigned int)bits };
    return u.value;
}

#define JB_RETAINED(object) ((__bridge_retained void *)(object))
#define JB_OBJECT(type, pointer) ((__bridge type *)(pointer))

void jb_retain(void *object) {
    CFRetain(object);
}

void jb_release(void *object) {
    CFRelease(object);
}

// MARK: - Concurrency

/// Embedded Swift emits `swift_deletedAsyncMethodError`, an async function that
/// hops with this concurrency runtime entry point, into every module. The game
/// has no async code, so instead of the runtime, this traps if it ever runs.
void swift_task_switch(void) {
    abort();
}

// MARK: - App

// From crt_externs.h, which the iOS SDK doesn't ship.
extern int *_NSGetArgc(void);
extern char ***_NSGetArgv(void);

static void (*jb_launched)(void *view);

@interface JBViewController : UIViewController
@end

@implementation JBViewController

- (void)loadView {
    SKView *view = [[SKView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.multipleTouchEnabled = NO;
    self.view = view;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end

@interface JBAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation JBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    JBViewController *controller = [[JBViewController alloc] init];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    jb_launched((__bridge void *)controller.view);
    return YES;
}

@end

int jb_main(void (*launched)(void *view)) {
    jb_launched = launched;
    @autoreleasepool {
        return UIApplicationMain(*_NSGetArgc(), *_NSGetArgv(), nil, NSStringFromClass([JBAppDelegate class]));
    }
}

void jb_open_url(const char *url) {
    NSURL *target = [NSURL URLWithString:@(url)];
    if (target) {
        [UIApplication.sharedApplication openURL:target];
    }
}

void jb_log(const void *bytes, unsigned long length) {
    NSString *message = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    NSLog(@"%@", message);
}

void jb_uptime_nanoseconds(unsigned long long *nanoseconds) {
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }
    *nanoseconds = mach_absolute_time() * timebase.numer / timebase.denom;
}

// MARK: - Files

long jb_file_exists(const char *path) {
    return access(path, F_OK) == 0;
}

char *jb_resource_path(void) {
    return strdup(NSBundle.mainBundle.resourcePath.fileSystemRepresentation);
}

char *jb_documents_path(void) {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return strdup(path.fileSystemRepresentation);
}

char *jb_file_read(const char *path, unsigned long *length) {
    NSData *data = [NSData dataWithContentsOfFile:@(path)];
    if (!data) {
        return NULL;
    }
    char *contents = malloc(data.length + 1);
    memcpy(contents, data.bytes, data.length);
    contents[data.length] = 0;
    *length = data.length;
    return contents;
}

long jb_file_write(const char *path, const void *bytes, unsigned long length) {
    return [[NSData dataWithBytes:bytes length:length] writeToFile:@(path) atomically:YES];
}

void jb_free(void *pointer) {
    free(pointer);
}

// MARK: - SKView

void jb_view_present_scene(void *view, void *scene) {
    [JB_OBJECT(SKView, view) presentScene:JB_OBJECT(SKScene, scene)];
}

void jb_view_set_ignores_sibling_order(void *view, long ignores) {
    JB_OBJECT(SKView, view).ignoresSiblingOrder = ignores != 0;
}

// MARK: - SKScene

static jb_scene_handlers jb_handlers;

@interface JBScene : SKScene
@property (nonatomic) void *context;
@end

@implementation JBScene

- (void)didMoveToView:(SKView *)view {
    jb_handlers.did_move(self.context, (__bridge void *)view);
}

- (void)update:(NSTimeInterval)currentTime {
    double time = currentTime;
    jb_handlers.update(self.context, &time);
}

- (void)forwardTouches:(NSSet<UITouch *> *)touches phase:(long)phase event:(UIEvent *)event {
    NSArray<UITouch *> *list = touches.allObjects;
    void *pointers[list.count];
    for (NSUInteger index = 0; index < list.count; index++) {
        pointers[index] = (__bridge void *)list[index];
    }
    jb_handlers.touches(self.context, phase, pointers, list.count, (__bridge void *)event);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forwardTouches:touches phase:0 event:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forwardTouches:touches phase:1 event:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forwardTouches:touches phase:2 event:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forwardTouches:touches phase:3 event:event];
}

@end

void jb_scene_set_handlers(const jb_scene_handlers *handlers) {
    jb_handlers = *handlers;
}

void *jb_scene_create(unsigned long width, unsigned long height) {
    return JB_RETAINED([[JBScene alloc] initWithSize:CGSizeMake(jb_float(width), jb_float(height))]);
}

void jb_scene_set_context(void *scene, void *context) {
    JB_OBJECT(JBScene, scene).context = context;
}

void jb_scene_set_background_color(void *scene, unsigned long red, unsigned long green,
                                   unsigned long blue, unsigned long alpha) {
    JB_OBJECT(SKScene, scene).backgroundColor =
        [UIColor colorWithRed:jb_float(red) green:jb_float(green) blue:jb_float(blue) alpha:jb_float(alpha)];
}

void jb_scene_set_scale_mode(void *scene, long mode) {
    JB_OBJECT(SKScene, scene).scaleMode = (SKSceneScaleMode)mode;
}

// MARK: - SKNode

void jb_node_add_child(void *node, void *child) {
    [JB_OBJECT(SKNode, node) addChild:JB_OBJECT(SKNode, child)];
}

void jb_node_remove_from_parent(void *node) {
    [JB_OBJECT(SKNode, node) removeFromParent];
}

void jb_node_set_position(void *node, unsigned long x, unsigned long y) {
    JB_OBJECT(SKNode, node).position = CGPointMake(jb_float(x), jb_float(y));
}

void jb_node_set_z_position(void *node, unsigned long z) {
    JB_OBJECT(SKNode, node).zPosition = jb_float(z);
}

void jb_node_set_z_rotation(void *node, unsigned long radians) {
    JB_OBJECT(SKNode, node).zRotation = jb_float(radians);
}

void jb_node_set_alpha(void *node, unsigned long alpha) {
    JB_OBJECT(SKNode, node).alpha = jb_float(alpha);
}

// MARK: - SKSpriteNode

void *jb_sprite_create(void *texture, unsigned long width, unsigned long height) {
    SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithTexture:JB_OBJECT(SKTexture, texture)
                                                          size:CGSizeMake(jb_float(width), jb_float(height))];
    return JB_RETAINED(sprite);
}

void jb_sprite_set_color(void *sprite, unsigned long red, unsigned long green,
                         unsigned long blue, unsigned long alpha) {
    JB_OBJECT(SKSpriteNode, sprite).color =
        [UIColor colorWithRed:jb_float(red) green:jb_float(green) blue:jb_float(blue) alpha:jb_float(alpha)];
}

void jb_sprite_set_color_blend_factor(void *sprite, unsigned long factor) {
    JB_OBJECT(SKSpriteNode, sprite).colorBlendFactor = jb_float(factor);
}

// MARK: - SKShapeNode

void *jb_shape_create_rect(unsigned long x, unsigned long y, unsigned long width, unsigned long height) {
    CGRect rect = CGRectMake(jb_float(x), jb_float(y), jb_float(width), jb_float(height));
    return JB_RETAINED([SKShapeNode shapeNodeWithRect:rect]);
}

void *jb_shape_create_path(void *path) {
    return JB_RETAINED([SKShapeNode shapeNodeWithPath:(CGPathRef)path]);
}

void jb_shape_set_fill_color(void *shape, unsigned long red, unsigned long green,
                             unsigned long blue, unsigned long alpha) {
    JB_OBJECT(SKShapeNode, shape).fillColor =
        [UIColor colorWithRed:jb_float(red) green:jb_float(green) blue:jb_float(blue) alpha:jb_float(alpha)];
}

void jb_shape_set_stroke_color(void *shape, unsigned long red, unsigned long green,
                               unsigned long blue, unsigned long alpha) {
    JB_OBJECT(SKShapeNode, shape).strokeColor =
        [UIColor colorWithRed:jb_float(red) green:jb_float(green) blue:jb_float(blue) alpha:jb_float(alpha)];
}

void jb_shape_set_line_width(void *shape, unsigned long width) {
    JB_OBJECT(SKShapeNode, shape).lineWidth = jb_float(width);
}

// MARK: - CGMutablePath

void *jb_path_create(void) {
    return CGPathCreateMutable();
}

void jb_path_move(void *path, unsigned long x, unsigned long y) {
    CGPathMoveToPoint((CGMutablePathRef)path, NULL, jb_float(x), jb_float(y));
}

void jb_path_add_line(void *path, unsigned long x, unsigned long y) {
    CGPathAddLineToPoint((CGMutablePathRef)path, NULL, jb_float(x), jb_float(y));
}

void jb_path_close(void *path) {
    CGPathCloseSubpath((CGMutablePathRef)path);
}

// MARK: - SKTexture and UIImage

void *jb_image_create(const char *path) {
    UIImage *image = [UIImage imageWithContentsOfFile:@(path)];
    return image ? JB_RETAINED(image) : NULL;
}

void *jb_texture_create(void *image) {
    return JB_RETAINED([SKTexture textureWithImage:JB_OBJECT(UIImage, image)]);
}

void *jb_texture_create_rect(void *texture, unsigned long x, unsigned long y,
                             unsigned long width, unsigned long height) {
    CGRect rect = CGRectMake(jb_float(x), jb_float(y), jb_float(width), jb_float(height));
    return JB_RETAINED([SKTexture textureWithRect:rect inTexture:JB_OBJECT(SKTexture, texture)]);
}

void jb_texture_size(void *texture, float *size) {
    CGSize textureSize = JB_OBJECT(SKTexture, texture).size;
    size[0] = textureSize.width;
    size[1] = textureSize.height;
}

void jb_texture_set_filtering_mode(void *texture, long mode) {
    JB_OBJECT(SKTexture, texture).filteringMode = (SKTextureFilteringMode)mode;
}

// MARK: - UITouch

void jb_touch_location(void *touch, void *node, float *point) {
    CGPoint location = [JB_OBJECT(UITouch, touch) locationInNode:JB_OBJECT(SKNode, node)];
    point[0] = location.x;
    point[1] = location.y;
}

// MARK: - Game controllers

static void (*jb_gamepad_button)(long button, long pressed);
static GCController *jb_controller;

static void jb_gamepad_observe(GCControllerButtonInput *input, long button) {
    input.pressedChangedHandler = ^(GCControllerButtonInput *input, float value, BOOL pressed) {
        jb_gamepad_button(button, pressed);
    };
}

static void jb_gamepad_attach(GCController *controller) {
    jb_controller = controller;
    // The extended profile is a superset of the standard one.
    GCGamepad *gamepad = controller.gamepad;
    if (!gamepad) {
        return;
    }
    jb_gamepad_observe(gamepad.buttonA, JB_GAMEPAD_A);
    jb_gamepad_observe(gamepad.dpad.up, JB_GAMEPAD_UP);
    jb_gamepad_observe(gamepad.dpad.down, JB_GAMEPAD_DOWN);
    jb_gamepad_observe(gamepad.dpad.left, JB_GAMEPAD_LEFT);
    jb_gamepad_observe(gamepad.dpad.right, JB_GAMEPAD_RIGHT);
    // The pause button only reports presses.
    controller.controllerPausedHandler = ^(GCController *controller) {
        jb_gamepad_button(JB_GAMEPAD_MENU, 1);
    };
}

void jb_gamepad_start(void (*button)(long button, long pressed)) {
    jb_gamepad_button = button;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:GCControllerDidConnectNotification object:nil
                         queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
        jb_gamepad_attach(notification.object);
    }];
    [center addObserverForName:GCControllerDidDisconnectNotification object:nil
                         queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
        if (notification.object == jb_controller) {
            jb_controller = nil;
        }
    }];
    GCController *existing = GCController.controllers.lastObject;
    if (existing) {
        jb_gamepad_attach(existing);
    }
}

long jb_gamepad_left_stick(float *axes) {
    GCControllerDirectionPad *stick = jb_controller.extendedGamepad.leftThumbstick;
    axes[0] = stick ? stick.xAxis.value : 0;
    axes[1] = stick ? stick.yAxis.value : 0;
    return stick != nil;
}

// MARK: - Audio

/// Keeps players alive while they play, since AVAudioPlayer doesn't.
@interface JBAudioPlayers : NSObject <AVAudioPlayerDelegate>
@property (nonatomic, strong) NSMutableSet<AVAudioPlayer *> *playing;
@end

@implementation JBAudioPlayers

- (instancetype)init {
    if ((self = [super init])) {
        _playing = [NSMutableSet set];
    }
    return self;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self.playing removeObject:player];
}

@end

static JBAudioPlayers *jb_audio_players(void) {
    static JBAudioPlayers *players;
    if (!players) {
        players = [[JBAudioPlayers alloc] init];
        // Mixes with other apps' audio and respects the silent switch.
        [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryAmbient error:nil];
    }
    return players;
}

void *jb_audio_load(const char *path) {
    NSData *data = [NSData dataWithContentsOfFile:@(path)];
    return data ? JB_RETAINED(data) : NULL;
}

void *jb_audio_play(void *audio) {
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithData:JB_OBJECT(NSData, audio) error:nil];
    if (!player) {
        return NULL;
    }
    JBAudioPlayers *players = jb_audio_players();
    player.delegate = players;
    [players.playing addObject:player];
    [player play];
    return JB_RETAINED(player);
}

long jb_audio_is_playing(void *player) {
    return JB_OBJECT(AVAudioPlayer, player).playing;
}

void jb_audio_stop(void *player) {
    AVAudioPlayer *audioPlayer = JB_OBJECT(AVAudioPlayer, player);
    [audioPlayer stop];
    [jb_audio_players().playing removeObject:audioPlayer];
}
