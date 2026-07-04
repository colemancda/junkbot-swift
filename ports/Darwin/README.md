# Junkbot Darwin port (macOS/iOS/tvOS)

Two separate projects, both rendering through **SpriteKit** rather than SDL - see "Why
SpriteKit, not SDL3" below for how this replaced the port's original SDL3-on-Apple-platforms
plan:

- **`Junkbot.xcodeproj`** - `Junkbot-macOS` and `Junkbot-tvOS` app targets.
- **`JunkbotPlayground.swiftpm`** - an iOS **App Playground** (opens in both Xcode 15+ and the
  Swift Playgrounds app). iOS used to be a third Xcode target here (`Junkbot-iOS`) - moved out
  to its own Playground so it can be opened/run directly in Swift Playgrounds on iPad, not just
  Xcode. See "The iOS Playground" below.

## What's shared vs. Darwin-only

- **Shared with `ports/SDL3`/`ports/SDL2`** (file references pointing directly at
  `../SDL3/Sources/JunkbotSDL3/*.swift` in `Junkbot.xcodeproj`; symlinks in
  `JunkbotPlayground.swiftpm`, the same technique `ports/SDL2` already uses to share files with
  `ports/SDL3`): `Screens.swift`, `TextRenderer.swift`, `GameRender.swift` (per-frame world/menu
  rendering - `renderWorld`/`render`/`VirtualCursor`/`TextureCache`), `GameInput.swift`
  (mouse/touch-to-world coordinate handling - `handleMouseDown/Move/Up`). `Renderer.swift` (the
  `GameRenderer` protocol), `Color.swift`, and `Button.swift` moved into `Sources/JunkbotCore`
  itself (they had zero SDL-specific imports) - both this project and `JunkbotPlayground.swiftpm`
  get them for free via `import JunkbotCore`, no file reference/symlink needed anymore.
  `main.swift`/`Input.swift` are **not** shared - both are genuinely SDL-specific (the blocking
  SDL event loop, SDL gamepad polling), unlike what the project's very first Darwin scaffold
  assumed when it included them as shared references.
- **Darwin-only** (`Sources/JunkbotDarwin/`, shared between `Junkbot.xcodeproj` and
  `JunkbotPlayground.swiftpm` via symlinks into the latter): `SpriteKitRenderer.swift` (the
  `GameRenderer` conformance - see below), `GameShell.swift` (the globals every shared file
  expects a port to provide: `repoRoot`, `gameEngine`, camera state, `levelCatalog`, sound/music
  stand-ins - the Darwin equivalent of the top of `ports/SDL3`'s `main.swift`), `GameScene.swift`
  (the `SKScene` subclass driving `gameEngine.tick()`/`render()` from SpriteKit's own `update(_:)`
  callback, plus mouse/touch input), `GameViewController.swift` (hosts the `SKView`/`JunkbotScene`
  - shared between the tvOS target's `AppDelegate_tvOS.swift`, which sets it as
  `window.rootViewController` directly, and the iOS Playground's SwiftUI `App`, which wraps it in
  a `UIViewControllerRepresentable` instead), `AppDelegate_macOS.swift` (AppKit window/`SKView`
  setup, macOS target only), `AppDelegate_tvOS.swift` (tvOS-only now - see above).
- `images/`, `font/`, `levels/`, `audio/`: Xcode **folder references** (blue folders, preserving
  subdirectory nesting) in `Junkbot.xcodeproj`'s Copy Bundle Resources phase; plain symlinks into
  `JunkbotPlayground.swiftpm/Sources/JunkbotPlayground/` declared as `resources:` in its
  `Package.swift` (SwiftPM resource paths can't escape the target directory with `../`, unlike
  Xcode's folder references, so the symlinks have to live inside `Sources/` itself). Either way,
  `Bundle.main.resourceURL` (`GameShell.swift`'s `repoRoot`) sees the exact same layout the SDL
  ports read via plain paths.
- A local Swift Package reference to the repo root, consuming the `JunkbotCore` product (both
  projects).

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
  `windowToRender`/`renderToWindow` use `SKView.convert(_:to:)`/`convert(_:from:)`, which already
  applies SpriteKit's own scene-scaling/letterboxing transform, plus the same Y-flip.
- `setTextureAlpha`/`setTextureColor` are stored in per-handle side tables and applied when a
  node is actually created in `drawTexture`, since SpriteKit applies alpha/color at the *node*
  level (`SKSpriteNode.alpha`/`.color`+`.colorBlendFactor`), not the *texture* level like SDL's
  `*AlphaMod`/`*ColorMod`.
- **Concurrency**: `SpriteKitRenderer` is declared `@MainActor`, conforming to `GameRenderer` via
  `@preconcurrency` (the protocol itself stays non-isolated, since `SDL3Renderer`/`SDL2Renderer`
  need to call e.g. `destroyTexture` from a `deinit`, which can't be main-actor-isolated) - every
  actual call site is already on the main actor (`GameScene.swift`'s `update(_:)`, all of
  `GameRender.swift`), so this is a real fix, not a suppression.

## The iOS Playground

`JunkbotPlayground.swiftpm` is an "App Playground" - a plain SwiftPM package with a special
`Package.swift` (`import AppleProductTypes`, a `.iOSApplication` product instead of a regular
`.executable`/`.library`) that Xcode 15+ and the Swift Playgrounds app both know how to open and
run as a full iOS app, no separate Xcode project needed. Structure:

- `Package.swift` - the `.iOSApplication` product (landscape-only via
  `supportedInterfaceOrientations: [.landscapeLeft, .landscapeRight]`, matching the old
  `Junkbot-iOS` target's build setting), a local path dependency on the repo root for
  `JunkbotCore`, and `resources:` pointing at the symlinked asset directories.
- `Sources/JunkbotPlayground/JunkbotPlaygroundApp.swift` - the SwiftUI `@main App`/`Scene` entry
  point (App Playgrounds boot through SwiftUI, not a `UIApplicationDelegate`), wrapping the
  shared `GameViewController` in a `UIViewControllerRepresentable`.
- Everything else in `Sources/JunkbotPlayground/` is a symlink into either
  `Sources/JunkbotDarwin/` or `../SDL3/Sources/JunkbotSDL3/` (see "What's shared vs. Darwin-only"
  above) plus the four symlinked asset directories.

**Not verified in this sandbox** - and likely not verifiable outside of Xcode/Swift Playgrounds
itself: `AppleProductTypes` is a module Xcode's own toolchain injects specifically when opening a
`.swiftpm` App Playground; it doesn't exist for plain command-line `swift build`/`swift package
describe` (confirmed: both fail with "no such module 'AppleProductTypes'" here), and `xcodebuild
-project JunkbotPlayground.swiftpm` doesn't recognize the bundle as a project either (App
Playgrounds are opened via `open JunkbotPlayground.swiftpm`/double-click, which routes through
Xcode's dedicated App Playground project loader, not the ordinary `-project`/`-workspace`
flags). The package's manifest and source layout were reviewed carefully against Apple's
documented App Playground format, but an actual build/run needs a real Xcode session (or Swift
Playgrounds on iPad) to confirm - flagged here for whoever picks that up, consistent with this
file's existing iOS/tvOS verification gaps below.

## Known gaps (not attempted this pass)

- **No gamepad/keyboard menu navigation** (the SDL ports' Phase 7 feature) - `GameShell.swift`
  declares `focusedButtonIndex`/`lastPointingInput`/`virtualCursorVisible` (required by the
  shared `Screens.swift`/`GameRender.swift`) but nothing ever sets them away from their
  mouse/no-focus defaults. Touch/mouse hit-testing (`GameScene.swift`) works standalone without
  needing them.
- **No audio.** `SoundBoard`/`MusicPlayer` in `GameShell.swift` are silent stand-ins. Real
  playback (`AVAudioPlayer`/`AVAudioEngine`, or SpriteKit's own `SKAction.playSoundFileNamed`)
  is a real follow-up - wiring the full `SoundID`/`MenuSoundID` tables was out of scope for the
  rendering-migration work this pass focused on.
- **tvOS is structurally sound but not build-verified in this environment** (no tvOS
  simulator/platform installed here - `xcodebuild` reports "tvOS 26.5 is not installed"). The
  **macOS** target was fully built (`xcodebuild build`, Debug) and run (`Junkbot-macOS.app`
  launched, stayed alive with no crash, correctly saw its bundled `images/font/levels/audio`
  folders under `Contents/Resources/`) - this is the one platform buildable/runnable without a
  simulator in this sandbox. A prior iOS Simulator build attempt (back when iOS was still an
  Xcode target here) hit a **pre-existing, unrelated** issue worth knowing about regardless of
  which iOS project you're using: `JunkbotCore`'s `swift-lingo` dependency
  (`LingoTranspilerPlugin`) fails to compile for the iOS Simulator SDK ("concurrency is only
  available in iOS 13.0.0 or newer") inside `swift-lingo`'s own `LingoAST` target, before any of
  this project's own code is even reached - a package-compatibility gap independent of anything
  in this repo, not investigated further (would mean digging into `swift-lingo`'s own
  `Package.swift` platform declarations).

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
open JunkbotPlayground.swiftpm      # iOS (Xcode or Swift Playgrounds)
```

Xcode will resolve the local `JunkbotCore` package dependency automatically in both cases. You'll
be prompted once to trust `swift-lingo`'s build tool plugin (`LingoTranspilerPlugin`) - approve
it, this is expected and not a security concern specific to this project. (From the command
line, pass `-skipPackagePluginValidation` to `xcodebuild` to bypass the one-time interactive
prompt - only relevant to `Junkbot.xcodeproj`, since `JunkbotPlayground.swiftpm` isn't drivable
via `xcodebuild` at all, see above.)
