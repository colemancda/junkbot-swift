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
| [`ports/Android`](ports/Android) | 🚧 Scaffold only | Package/Gradle project skeleton; not compiled or run yet. |

See each port's own README (where present) for build details, and root `.github/workflows/` for
what's verified in CI.
