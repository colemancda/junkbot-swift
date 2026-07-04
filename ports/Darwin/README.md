# Junkbot Darwin port (macOS/iOS/tvOS)

`Junkbot.xcodeproj` has three app targets (`Junkbot-macOS`, `Junkbot-iOS`, `Junkbot-tvOS`), all
rendering through **SpriteKit** rather than SDL - see "Why SpriteKit, not SDL3" below for how
this replaced the port's original SDL3-on-Apple-platforms plan.

## What's shared vs. Darwin-only

- **Shared with `ports/SDL3`/`ports/SDL2`** (file references pointing directly at
  `../SDL3/Sources/JunkbotSDL3/*.swift` - no copy, no symlink; Xcode supports referencing files
  outside the project directory natively): `Renderer.swift` (the `GameRenderer` protocol),
  `Color.swift`, `Button.swift`, `Screens.swift`, `TextRenderer.swift`, `GameRender.swift`
  (per-frame world/menu rendering - `renderWorld`/`render`/`VirtualCursor`/`TextureCache`),
  `GameInput.swift` (mouse/touch-to-world coordinate handling - `handleMouseDown/Move/Up`).
  `main.swift`/`Input.swift` are **not** shared - both are genuinely SDL-specific (the blocking
  SDL event loop, SDL gamepad polling), unlike what the project's very first Darwin scaffold
  assumed when it included them as shared references.
- **Darwin-only** (`Sources/JunkbotDarwin/`): `SpriteKitRenderer.swift` (the `GameRenderer`
  conformance - see below), `GameShell.swift` (the globals every shared file expects a port to
  provide: `repoRoot`, `gameEngine`, camera state, `levelCatalog`, sound/music stand-ins - the
  Darwin equivalent of the top of `ports/SDL3`'s `main.swift`), `GameScene.swift` (the `SKScene`
  subclass driving `gameEngine.tick()`/`render()` from SpriteKit's own `update(_:)` callback,
  plus mouse/touch input), `AppDelegate_macOS.swift` (AppKit window/`SKView` setup, macOS target
  only), `AppDelegate_iOS.swift` (UIKit window/`SKView` setup, iOS **and** tvOS targets - their
  lifecycle APIs are close enough to share one file).
- `images/`, `font/`, `levels/`, `audio/` as Xcode **folder references** (blue folders,
  preserving subdirectory nesting) in each target's Copy Bundle Resources phase -
  `Bundle.main.resourceURL` (`GameShell.swift`'s `repoRoot`) sees the exact same layout the SDL
  ports read via plain paths.
- A local Swift Package reference to the repo root, consuming the `JunkbotCore` product.

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
  C-struct import limitation - see `Renderer.swift`'s doc comment). SpriteKit has no such
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
- **iOS/tvOS builds are structurally sound but not fully build-verified in this environment.**
  `xcodebuild -list` resolves the package graph and lists all three targets/schemes correctly.
  The **macOS** target was fully built (`xcodebuild build`, Debug) and run (`Junkbot-macOS.app`
  launched, stayed alive with no crash, correctly saw its bundled `images/font/levels/audio`
  folders under `Contents/Resources/`) - this is the one platform buildable/runnable without a
  simulator in this sandbox. An iOS Simulator build attempt hit a **pre-existing, unrelated**
  issue: the `swift-lingo` package dependency (`JunkbotCore`'s `LingoTranspilerPlugin`) fails to
  compile for the iOS Simulator SDK here ("concurrency is only available in iOS 13.0.0 or
  newer") - this happens inside `swift-lingo`'s own `LingoAST` target, before any of this
  project's own Darwin/shared code is even reached, so it's a package-compatibility gap
  independent of the SpriteKit migration. Not investigated further this pass (would mean digging
  into `swift-lingo`'s own `Package.swift` platform declarations) - flagged here for whoever
  picks up real iOS/tvOS device or simulator testing.
- **Landscape-only iOS lock** is applied as a build setting
  (`INFOPLIST_KEY_UISupportedInterfaceOrientations` = landscape-left/right, both phone and iPad
  idioms, on the `Junkbot-iOS` target only - `GENERATE_INFOPLIST_FILE = YES` means there's no
  checked-in `Info.plist` to edit directly) plus `GameViewController.supportedInterfaceOrientations`
  in `AppDelegate_iOS.swift`. Not verified on a real device/simulator, for the reason above.

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

## Opening the project

```
open Junkbot.xcodeproj
```

Xcode will resolve the local `JunkbotCore` package dependency automatically. You'll be prompted
once to trust `swift-lingo`'s build tool plugin (`LingoTranspilerPlugin`) - approve it, this is
expected and not a security concern specific to this project. (From the command line, pass
`-skipPackagePluginValidation` to `xcodebuild` to bypass the one-time interactive prompt.)
