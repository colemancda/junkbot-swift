# Junkbot Darwin port (macOS/iOS/tvOS)

Two separate projects, both rendering through **SpriteKit** rather than SDL - see "Why
SpriteKit, not SDL3" below for how this replaced the port's original SDL3-on-Apple-platforms
plan:

- **`Junkbot.xcodeproj`** - `Junkbot-macOS` and `Junkbot-tvOS` app targets.
- **`JunkbotMobile.swiftpm`** - an iOS **App Playground** (opens in both Xcode 15+ and the
  Swift Playgrounds app). iOS used to be a third Xcode target here (`Junkbot-iOS`) - moved out
  to its own Playground so it can be opened/run directly in Swift Playgrounds on iPad, not just
  Xcode. See "The iOS Playground" below.

## What's shared vs. Darwin-only

- **Shared with `ports/SDL3`/`ports/SDL2`** (file references pointing directly at
  `../SDL3/Sources/JunkbotSDL3/*.swift` in `Junkbot.xcodeproj`; symlinks in
  `JunkbotMobile.swiftpm`, the same technique `ports/SDL2` already uses to share files with
  `ports/SDL3`): `Screens.swift`, `TextRenderer.swift`, `GameRender.swift` (per-frame world/menu
  rendering - `renderWorld`/`render`/`VirtualCursor`/`TextureCache`), `GameInput.swift`
  (mouse/touch-to-world coordinate handling - `handleMouseDown/Move/Up`), `MenuFocus.swift`
  (keyboard/d-pad menu focus navigation - `moveFocus`/`directionPressed`/`nudgeDrag`/
  `activatePressed`/`activateReleased` - extracted from `ports/SDL3`'s `Input.swift` since none
  of it touches SDL/GameController directly). `Renderer.swift` (the `GameRenderer` protocol),
  `Color.swift`, and `Button.swift` moved into `Sources/JunkbotCore` itself (they had zero
  SDL-specific imports) - both this project and `JunkbotMobile.swiftpm` get them for free via
  `import JunkbotCore`, no file reference/symlink needed anymore. `main.swift`/`Input.swift` are
  **not** shared - both are genuinely SDL-specific (the blocking SDL event loop, raw SDL gamepad
  polling); Darwin has its own `GamepadInput.swift` instead (see below) providing the same
  `hideOSCursor`/`warpCursor`/`notePointingInput` seam `MenuFocus.swift` calls into.
- **Darwin-only** (`Sources/JunkbotDarwin/`, shared between `Junkbot.xcodeproj` and
  `JunkbotMobile.swiftpm` via symlinks into the latter): `SpriteKitRenderer.swift` (the
  `GameRenderer` conformance - see below), `GameShell.swift` (the globals every shared file
  expects a port to provide: `repoRoot`, `gameEngine`, camera state, `levelCatalog` - the Darwin
  equivalent of the top of `ports/SDL3`'s `main.swift`), `Audio.swift` (real `SoundBoard`/
  `MusicPlayer`, `AVAudioPlayer`-backed - see "Audio" below), `GamepadInput.swift`
  (`GameController.framework`-backed gamepad/keyboard input - see "Gamepad + keyboard input"
  below), `GameScene.swift` (the `SKScene` subclass driving `gameEngine.tick()`/`render()` from
  SpriteKit's own `update(_:)` callback, plus mouse/touch/stick input), `GameViewController.swift`
  (hosts the `SKView`/`JunkbotScene` - shared between the tvOS target's `AppDelegate_tvOS.swift`,
  which sets it as `window.rootViewController` directly, and the iOS Playground's SwiftUI `App`,
  which wraps it in a `UIViewControllerRepresentable` instead), `AppDelegate_macOS.swift` (AppKit
  window/`SKView` setup, macOS target only), `AppDelegate_tvOS.swift` (tvOS-only now - see
  above).
- `images/`, `font/`, `levels/`: Xcode **folder references** (blue folders, preserving
  subdirectory nesting) in `Junkbot.xcodeproj`'s Copy Bundle Resources phase; plain symlinks into
  `JunkbotMobile.swiftpm/Sources/JunkbotMobile/` declared as `resources:` in its
  `Package.swift` (SwiftPM resource paths can't escape the target directory with `../`, unlike
  Xcode's folder references, so the symlinks have to live inside `Sources/` itself). Either way,
  `Bundle.main.resourceURL` (`GameShell.swift`'s `repoRoot`) sees the exact same layout the SDL
  ports read via plain paths. `audio/` is deliberately **not** bundled raw on Darwin - see
  "Audio" below.
- `Junkbot.xcodeproj` uses a local Swift Package reference to the repo root, consuming the
  `JunkbotCore` product. `JunkbotMobile.swiftpm` instead picks its `JunkbotCore` dependency
  conditionally in `Package.swift` based on `#if os(macOS)`: a local `path: "../.."` dependency
  when the manifest is parsed on a Mac (Xcode - edits to `Sources/JunkbotCore` show up
  immediately), or `.package(url: "https://github.com/colemancda/junkbot-swift.git", branch:
  "main")` everywhere else - the Swift Playgrounds app on iPad/iPhone only has this `.swiftpm`
  bundle itself, sandboxed, with no sibling `ports/`/`Sources/` directories a `path:` dependency
  could resolve against, so it needs to fetch `JunkbotCore` from GitHub to build standalone. Note
  `#if os()` here checks the platform actually *running* the manifest (Xcode's loader vs. Swift
  Playgrounds' own on-device one), not the platform being built for.

## SpriteKit as a rendering-only backend

`SpriteKitRenderer.swift` implements the same `GameRenderer` protocol `SDL3Renderer`/
`SDL2Renderer` implement, using SpriteKit purely as an immediate-mode blitter:

- **No `SKPhysicsBody`/`SKPhysicsWorld` anywhere.** `GameEngine`/`JunkbotCore` remains the sole
  simulation authority, exactly as on every other port - `GameScene.swift`'s `update(_:)` only
  ever calls `gameEngine.tick()`.
- Each draw call (`fillRect`/`drawTexture`/`fillTriangle`/etc.) adds a fresh `SKNode` to the
  scene; `clear()` removes every node added by the previous frame. This reimplements the same
  "redraw the whole command list every frame" model `SDL3Renderer`/`SDL2Renderer` already use, on
  top of a fundamentally retained scene graph, via node churn rather than a persistent node
  hierarchy.
- **Texture handles**: `GameRenderer`'s texture type is `OpaquePointer` (chosen for SDL2's opaque
  C-struct import limitation - see `Sources/JunkbotCore/GameRenderer.swift`'s doc comment).
  SpriteKit has no such
  constraint (`SKTexture` is a perfectly nameable Swift class), so textures are tracked in a side
  table keyed by a small integer handle, and `OpaquePointer(bitPattern:)` wraps that integer
  purely to satisfy the protocol's type signature - the bit pattern is never dereferenced, only
  round-tripped back through `Int(bitPattern:)` to look the texture up.
- **Coordinate system**: SpriteKit is Y-up with the origin at the scene's bottom-left; the
  `GameRenderer` protocol (and every other backend) is Y-down, origin top-left. `flippedY(_:
  height:)` converts at every draw call, including inside `SKTexture(rect:in:)` sub-region
  clipping math (which is itself Y-up relative to the *texture's* own height, not the scene's).
  `windowToRender`/`renderToWindow` only apply that Y-flip - `GameScene.swift`'s callers already
  hand them `event.location(in: self)`/`touch.location(in: self)` (scene-space, via SpriteKit's
  own `NSEvent`/`UITouch` extensions, already accounting for `scaleMode`/letterboxing), so no
  further `SKView.convert(_:to:)` is needed; running an already-scene-space point back through
  `convert(_:to:)` double-applies the transform (a real bug fixed here). Why it looked fine on
  macOS but not iOS: `NSView`'s coordinate system is *already* bottom-left/Y-up like SpriteKit's
  own, so the redundant re-conversion there was a near no-op; `UIView`'s is top-left/Y-down, so
  the same redundant call introduced a real Y-flip-plus-offset error, which is why touch input on
  iOS looked "inverted"/grabbed bricks far from the actual touch point while mouse on macOS looked
  fine.
- `setTextureAlpha`/`setTextureColor` are stored in per-handle side tables and applied when a
  node is actually created in `drawTexture`, since SpriteKit applies alpha/color at the *node*
  level (`SKSpriteNode.alpha`/`.color`+`.colorBlendFactor`), not the *texture* level like SDL's
  `*AlphaMod`/`*ColorMod`.
- **Concurrency**: `SpriteKitRenderer` is declared `@MainActor`, conforming to `GameRenderer` via
  `@preconcurrency` (the protocol itself stays non-isolated, since `SDL3Renderer`/`SDL2Renderer`
  need to call e.g. `destroyTexture` from a `deinit`, which can't be main-actor-isolated) - every
  actual call site is already on the main actor (`GameScene.swift`'s `update(_:)`, all of
  `GameRender.swift`), so this is a real fix, not a suppression.

## Audio

`Audio.swift`'s `SoundBoard`/`MusicPlayer` mirror `ports/SDL3`'s SDL3_mixer-backed classes of the
same name verbatim - same `SoundID`/filename tables, same 5 randomized level-music playlists +
fade-out stings - just built on `AVAudioPlayer` instead of `MIX_*` calls:

- `SoundBoard.play(id:)` creates a fresh `AVAudioPlayer` per call (an `ActiveSoundEffect` wrapper
  keeps it alive via `AVAudioPlayerDelegate` until playback finishes, then self-removes), so
  overlapping playback of the same sound (e.g. rapid water drips) works, mirroring SDL_mixer's
  auto-pick-a-free-channel behavior instead of one reused player per sound.
- `MusicPlayer.update()` polls `.isPlaying` each frame (`GameScene.swift`'s `update(_:)` already
  called this every frame before this pass, when it was a no-op) - same poll-based design as
  `ports/SDL3`'s `!MIX_TrackPlaying(track)` check.

**Almost every asset under `audio/` is Ogg Vorbis, a format `AVAudioPlayer` can't decode** -
confirmed empirically that macOS's built-in `afconvert` tool *can* decode `.ogg` directly when run
unsandboxed (not an Apple-documented supported input format, but the codec component is present),
so audio is transcoded to Core Audio Format (`.caf`) instead of shipping a third-party Ogg decoder:

- `Scripts/transcode-audio.sh` is the actual transcoding logic (`afconvert -f caff -d
  LEI16@44100`, skip-if-newer for fast incremental runs, tolerant of individual file failures),
  shared between both consumers below.
- `Junkbot.xcodeproj`: a Run Script build phase on both `Junkbot-macOS` and `Junkbot-tvOS`,
  writing into `$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/TranscodedAudio/` at every
  build. Named `TranscodedAudio` (not `Audio`) deliberately - macOS's case-insensitive-by-default
  filesystem means a folder named `Audio` would collide with (and get corrupted by) the
  *original* `audio` folder reference if one existed at the same path; the raw `audio` folder
  reference was removed from Copy Bundle Resources entirely once this landed, since only the
  transcoded `.caf` files are actually read at runtime.
- `JunkbotMobile.swiftpm`: originally used a `Plugins/TranscodeAudioPlugin` SwiftPM
  build-tool plugin (`prebuildCommand`) to invoke the same script at build time - **removed**,
  since SwiftPM always runs plugins sandboxed with no opt-out, and `afconvert` cannot decode Ogg
  Vorbis from inside that sandbox (confirmed: the identical `afconvert` invocation that works
  fine in the Xcode Run Script phases above - unsandboxed - failed with "Couldn't open input
  file" when run from inside the plugin's subprocess; every `.ogg`-sourced sound was silently
  missing, only the handful of already-`.wav` ones transcoded successfully). Instead,
  `Scripts/transcode-audio.sh` is run manually once (whenever `audio/` changes) directly into
  `Sources/JunkbotMobile/TranscodedAudio/`, which is checked in as real files (not a symlink,
  unlike `images`/`font`/`levels`) and declared as a plain `.copy(...)` resource in
  `Package.swift` - see that file's doc comment for the exact invocation.

## Gamepad + keyboard input

`GamepadInput.swift` is the Darwin equivalent of `ports/SDL3`'s `Input.swift` (Phase 7), built on
`GameController.framework` instead of raw SDL calls:

- `GCController`/`GCExtendedGamepad` for full gamepads; falls back to `GCMicroGamepad` (dpad +
  one button) when `extendedGamepad` is `nil` - the profile tvOS's Siri Remote actually exposes.
  **This is what makes tvOS playable at all**, not just a nice-to-have: `GameScene.swift`'s touch
  handlers never fire on tvOS (no touchscreen), so before this pass tvOS had *no working input
  path whatsoever* despite building successfully - a worse gap than this file previously
  documented.
- `GCKeyboard.coalesced?.keyboardInput` covers physical keyboards uniformly across macOS/iOS/
  tvOS via the same framework, so - unlike the SDL ports - there's no separate `NSEvent`/
  `UIKeyCommand` path to maintain.
- The actual menu-focus navigation logic (`moveFocus`/`directionPressed`/`activatePressed`/etc.)
  lives in the shared `MenuFocus.swift` (see above) - this file only provides the raw
  stick/button/key event handling plus the two neutral wrappers `MenuFocus.swift` calls into
  (`hideOSCursor`/`warpCursor`: `NSCursor.hide()`/`.unhide()` on macOS, no-op on iOS/tvOS, since
  there's no meaningful OS cursor there - the shared virtual-cursor drawing in `GameRender.swift`
  takes over automatically once `lastPointingInput`/`virtualCursorVisible` are driven correctly,
  with zero new drawing code needed).
- **A real Swift 6 strict-concurrency wrinkle worth knowing about**: `GameController` isn't yet
  Sendable-audited, so capturing a `GCController` across a `NotificationCenter` closure boundary
  (hotplug connect/disconnect) was flagged as a potential data race by the compiler even though
  `queue: .main` guarantees it can't actually race. Neither wrapping the callback in
  `Task { @MainActor in }` nor `MainActor.assumeIsolated` satisfied the checker (both still
  treated the non-Sendable `GCController`/`Notification` payload as unsafely "sent" across the
  closure boundary) - the fix was `@preconcurrency import GameController`, which is exactly what
  that annotation is for: telling the compiler to trust an as-yet-unaudited system framework's
  types the way pre-Swift-6 code did, rather than fighting isolation-region diagnostics over a
  case the framework's own author hasn't resolved yet.

Not verified on a real gamepad/keyboard in this sandbox (no hardware controller attached) -
verified only via a clean build + smoke-test run (`Junkbot-macOS.app` launches, stays alive, no
crash) and careful API review against Apple's documented `GameController`/`AVFoundation`
behavior.

## The iOS Playground

`JunkbotMobile.swiftpm` is an "App Playground" - a plain SwiftPM package with a special
`Package.swift` (`import AppleProductTypes`, a `.iOSApplication` product instead of a regular
`.executable`/`.library`) that Xcode 15+ and the Swift Playgrounds app both know how to open and
run as a full iOS app, no separate Xcode project needed. Structure:

- `Package.swift` - the `.iOSApplication` product (landscape-only via
  `supportedInterfaceOrientations: [.landscapeLeft, .landscapeRight]`, matching the old
  `Junkbot-iOS` target's build setting), a `JunkbotCore` dependency that's a local `path:` on
  macOS or a GitHub `url:` everywhere else (see "What's shared vs. Darwin-only" above), and
  `resources:` pointing at the symlinked asset directories.
- `Sources/JunkbotMobile/JunkbotMobileApp.swift` - the SwiftUI `@main App`/`Scene` entry
  point (App Playgrounds boot through SwiftUI, not a `UIApplicationDelegate`), wrapping the
  shared `GameViewController` in a `UIViewControllerRepresentable`.
- Everything else in `Sources/JunkbotMobile/` is a symlink into either
  `Sources/JunkbotDarwin/` or `../SDL3/Sources/JunkbotSDL3/` (see "What's shared vs. Darwin-only"
  above) plus the four symlinked asset directories.

**Build-verified via `xcodebuild` on the command line** (previously assumed not to be possible -
corrected here): `AppleProductTypes` is a module Xcode's own toolchain injects specifically when
opening a `.swiftpm` App Playground, so it doesn't exist for plain command-line `swift build`/
`swift package describe` (confirmed: both fail with "no such module 'AppleProductTypes'"), and
`xcodebuild -project JunkbotMobile.swiftpm` doesn't recognize the bundle as a project either -
but `xcodebuild` **does** auto-detect a `.swiftpm` App Playground from the current directory the
same way it auto-detects a plain `Package.swift`, with no `-project`/`-workspace` flag at all:

```sh
cd ports/Darwin/JunkbotMobile.swiftpm
xcodebuild build -scheme JunkbotMobile -destination "generic/platform=iOS Simulator" \
  -skipPackagePluginValidation
```

Confirmed working end-to-end (`** BUILD SUCCEEDED **`, real `JunkbotMobile.app` produced under
`Debug-iphonesimulator/`) - this is what CI now uses (see root `.github/workflows/swift.yml`'s
`darwin-ios` job).

## Known gaps (not attempted this pass)

- **tvOS is structurally sound and confirmed buildable, but not build-verified end-to-end in
  this sandbox**: the tvOS *SDK* is installed (`xcodebuild -showsdks` lists `appletvos26.5`), but
  no destination is eligible without the separate tvOS *platform*/simulator runtime, which
  `xcodebuild -downloadPlatform tvOS` confirms is a real, working ~3.76GB download (kicked off
  successfully here, just not completed - too large/slow for this sandbox's time budget). CI
  (`darwin-tvos` in `.github/workflows/swift.yml`) runs that download step before building, since
  GitHub's runner image can't be assumed to have every platform pre-installed either. The
  **macOS** target was fully built (`xcodebuild build`, Debug) and run (`Junkbot-macOS.app`
  launched, stayed alive with no crash, correctly saw its bundled `images/font/levels` folders
  and transcoded `TranscodedAudio/` under `Contents/Resources/`) - this remains the one platform
  buildable/runnable without any extra platform download in this sandbox. **iOS is now fully
  build-verified** here too (see "The iOS Playground" above) - a previously-noted concern about
  `swift-lingo`'s `LingoAST` target failing to compile for the iOS Simulator SDK ("concurrency is
  only available in iOS 13.0.0 or newer") turned out not to reproduce against the current
  `JunkbotMobile.swiftpm` (`platforms: [.iOS("26.0")]`, well above whatever old deployment target
  the original iOS Xcode target used when that issue was last seen) - the build now succeeds
  cleanly with no workaround needed.
- **Gamepad/keyboard input and audio are implemented but not verified on real hardware** in this
  sandbox (no controller/keyboard peripheral or audio output to test against) - see "Audio" and
  "Gamepad + keyboard input" above for what was verified instead (clean builds, smoke-test runs,
  careful API review).

## Why SpriteKit, not SDL3

An earlier pass tried to bring SDL3 to Apple platforms (see git history for the original
"Known, unresolved gap: SDL3 on Apple platforms" section this replaced) and found real blockers:
Homebrew's SDL3 is macOS-host-only, SDL3 has no official SwiftPM package, and neither
`SDL3_image` nor `SDL3_mixer` ship a ready Apple XCFramework anywhere - `KevinVitale/SwiftSDL`
vendors an `SDL3.xcframework` but doesn't expose an importable C module for it as a public
product. None of that mattered by the time this project (SDL3/SDL2 desktop, Web/WASM, this
Darwin port) already had a `GameRenderer` protocol seam cleanly separating rendering from
simulation - reimplementing that one seam against SpriteKit (which ships with every Apple SDK,
no vendoring needed) was far less work than solving the SDL3_image/SDL3_mixer XCFramework gap,
and this port never needs SDL's audio/windowing/gamepad pieces anyway (those stay platform-native
here: AppKit/UIKit windowing, and audio/gamepad are open follow-ups either way).

## Opening the projects

```
open Junkbot.xcodeproj              # macOS + tvOS
open JunkbotMobile.swiftpm      # iOS (Xcode or Swift Playgrounds)
```

Xcode will resolve the local `JunkbotCore` package dependency automatically in both cases. You'll
be prompted once to trust `swift-lingo`'s build tool plugin (`LingoTranspilerPlugin`) - approve
it, this is expected and not a security concern specific to this project. (From the command
line, pass `-skipPackagePluginValidation` to `xcodebuild` to bypass the one-time interactive
prompt - only relevant to `Junkbot.xcodeproj`, since `JunkbotMobile.swiftpm` isn't drivable
via `xcodebuild` at all, see above.)
