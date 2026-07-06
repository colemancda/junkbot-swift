# swift-junkbot

A Swift remake of LEGO [Junkbot](https://history.jakelee.co.uk/lego-junkbot-technical-and-historical-decompiling/).

<img width="1180" height="820" alt="Screenshot 2026-07-04 at 10 43 38 AM" src="https://github.com/user-attachments/assets/bf0c2a6d-6833-4f9a-8ade-b36490b05d22" />

## Ports

The core game/simulation logic (`Sources/JunkbotCore`) is shared across several native targets
under `ports/`:

| Port | Status | Notes |
| --- | --- | --- |
| [`ports/Web`](ports/Web) | ✅ Working | WASM build (`make all` from the repo root), loaded by the HTML5 frontend. |
| [`ports/SDL2`](ports/SDL2) | ✅ Working | Native desktop build against SDL2/SDL2_image/SDL2_mixer (via [PureSwift/SDL](https://github.com/PureSwift/SDL)). |
| [`ports/SDL3`](ports/SDL3) | ✅ Working | Same as SDL2, against SDL3/SDL3_image/SDL3_mixer. |
| [`ports/Darwin`](ports/Darwin) | ✅ Working | SpriteKit-based native app: `Junkbot-macOS`/`Junkbot-tvOS` (`Junkbot.xcodeproj`) and `JunkbotMobile` (`JunkbotMobile.swiftpm`, a Swift Playgrounds App Playground for iOS). All three build in CI; macOS is confirmed running end-to-end. |
| [`ports/portmaster`](ports/portmaster) | 🚧 Packaging scaffold | Bundles the SDL2/SDL3 builds for [PortMaster](https://portmaster.games/) handheld distribution; not yet tested on real hardware. |
| [`ports/Android`](ports/Android) | ✅ Working | Cross-compiled Swift (`JunkbotCore` + the SDL3 game code shared with `ports/SDL3`) in a Java `SDLActivity` shell. Verified end-to-end on an emulator: title screen, level loading, sprite rendering, touch input. |
| [`ports/N64`](ports/N64) | ✅ Working | Nintendo 64 build in Embedded Swift (mips-none-none-elf) against the open-source [libdragon](https://github.com/DragonMinded/libdragon) SDK; software-rasterized (no RDP texture pipeline - TMEM is too small for the sprite count). Verified end-to-end in ares: analog-stick/D-pad-driven cursor grab/drag/drop, sound effects/music, HUD overlay, level switching. |
| [`ports/NDS`](ports/NDS) | ✅ Working | Nintendo DS build in Embedded Swift (armv5te), no maxmod/streaming. Verified end-to-end in melonDS: touch-drag gameplay on the bottom screen, sound effects/music, and a bitmap-font info panel on the top screen. |
| [`ports/3DS`](ports/3DS) | ✅ Builds | Embedded Swift ARM11 build; same scrollable-bottom-screen design as `ports/NDS`. Builds and links end-to-end; not yet run on real hardware or an emulator. |

See each port's own README (where present) for build details, and root `.github/workflows/` for
what's verified in CI.
