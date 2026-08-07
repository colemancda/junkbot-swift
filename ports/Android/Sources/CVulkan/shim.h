// Bridges the Android NDK's own Vulkan headers (ships `vulkan/vulkan.h` plus the
// `vulkan/vulkan_android.h` platform header under the NDK sysroot - no separate Vulkan SDK
// install needed) into a Swift-importable module, following the exact pattern
// `ports/Android/Sources/CAndroidLooper/shim.h` already uses for `<android/looper.h>`.
//
// `VK_USE_PLATFORM_ANDROID_KHR` must be defined *before* including `vulkan.h` to pull in
// `VkAndroidSurfaceCreateInfoKHR`/`vkCreateAndroidSurfaceKHR` (used to build a `VkSurfaceKHR`
// straight from the `ANativeWindow` SDL's own Vulkan glue exposes via `SDL_Vulkan_CreateSurface`
// - see `Vulkan3DManager.swift`'s doc comment for why raw `SDL_Vulkan_*` calls are used instead of
// hand-rolling `ANativeWindow` access ourselves).
#define VK_USE_PLATFORM_ANDROID_KHR
#include <vulkan/vulkan.h>

// `PureSwift/SDL`'s own `CSDL3` module only includes `<SDL3/SDL.h>` (the umbrella header), which
// does *not* pull in `SDL_vulkan.h` - `SDL_Vulkan_GetInstanceExtensions`/`SDL_Vulkan_CreateSurface`
// (used by `Vulkan3DManagerSetup.swift` to build the `VkInstance`/`VkSurfaceKHR`) are invisible
// through `import CSDL3` alone. Included here instead, after `vulkan.h` above, so its own
// `#ifdef VULKAN_CORE_H_` guard skips its duplicate `VkInstance`/`VkSurfaceKHR` typedefs and reuses
// the real ones from `vulkan.h` - one consistent set of Vulkan handle types, not two clashing ones
// from two separately-compiled Clang modules.
#include <SDL3/SDL_vulkan.h>
