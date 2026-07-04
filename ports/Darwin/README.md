# Junkbot Darwin port (macOS/iOS/tvOS)

`Junkbot.xcodeproj` has three app targets (`Junkbot-macOS`, `Junkbot-iOS`, `Junkbot-tvOS`)
sharing:
- The same Swift source as `ports/SDL3` — file references pointing directly at
  `../SDL3/Sources/JunkbotSDL3/*.swift` (no copy, no symlink; Xcode supports referencing files
  outside the project directory natively).
- `images/`, `font/`, `levels/`, `audio/` as Xcode **folder references** (blue folders,
  preserving subdirectory nesting) in each target's Copy Bundle Resources phase, so
  `Bundle.main.resourceURL` sees the exact same layout the SDL3 port reads via plain paths (see
  `repoRoot`'s Apple-platform branch in `ports/SDL3/Sources/JunkbotSDL3/main.swift`).
- A local Swift Package reference to the repo root, consuming the `JunkbotCore` product.

**Validated**: `xcodebuild -list -project Junkbot.xcodeproj` resolves the package graph
(`JunkbotCore` + its `swift-lingo` dependency) and lists all three targets/schemes correctly —
confirmed structurally sound. A full build was *not* completed in the environment this was
authored in (no iOS/tvOS SDK build of SDL3_image/SDL3_mixer available, see below) — the first
`xcodebuild build` attempt got as far as Xcode's one-time build-tool-plugin trust prompt for
`swift-lingo`'s `LingoTranspilerPlugin` (expected — approve it once by opening the project in
Xcode's GUI, or accept the equivalent CLI prompt).

## Known, unresolved gap: SDL3 on Apple platforms

**This project does not yet link against SDL3, SDL3_image, or SDL3_mixer at all.** The shared
source still says `import CSDL3`/`CSDL3Image`/`CSDL3Mixer` unchanged, so a full build will fail
with "no such module" until this is wired up. Here's what was investigated and why it isn't
already done:

- Homebrew's SDL3 (used by `ports/SDL3`) is a macOS-host-only dylib - unusable for iOS/tvOS
  device or simulator builds.
- SDL3 itself has no official SwiftPM package.
- `KevinVitale/SwiftSDL` (github.com/KevinVitale/SwiftSDL) vendors a prebuilt `SDL3.xcframework`
  for macOS/iOS/tvOS via a `.binaryTarget`, which is exactly the right *technique* - **but its
  own C-import wrapper target (`CSDL`) is not declared as a public product** in its
  `Package.swift` (only `SwiftSDL` and a test-bench executable are). Depending on SwiftSDL as a
  package dependency does **not** give you an importable `CSDL3`/`CSDL` module - only its
  higher-level Swift API (`SwiftSDL`), which this codebase doesn't use.
- `SDL3_image`/`SDL3_mixer` have no ready-made Apple XCFramework anywhere (checked their GitHub
  releases directly - only Windows/mingw/Android/source assets exist).

### What actually needs to happen here

1. Vendor `SDL3.xcframework` yourself - either build it from source via the Xcode project
   template in SDL3's own repo (`Xcode/SDL/`, which has a script to produce an xcframework), or
   extract it from a `SwiftSDL` checkout's `Dependencies/SDL3.xcframework` (check that package's
   license/redistribution terms before doing this).
2. Do the same for `SDL3_image`/`SDL3_mixer` - these will need a **from-source** Xcode/CMake
   build, since no one ships a ready Apple XCFramework for them.
3. Add each `.xcframework` as a `.binaryTarget`-equivalent in this Xcode project (or wrap it as a
   proper Swift package the way SwiftSDL does), with a small C target/module map named exactly
   `CSDL3`/`CSDL3Image`/`CSDL3Mixer` (matching what the shared Swift source already imports) that
   exposes the XCFramework's headers - mirroring `SwiftSDL`'s own "CSDL" wrapper technique, just
   under names that match this project's existing imports instead of introducing new ones.
4. Link each of the three app targets against all three.

This is real, non-trivial platform work that needs a Mac with the iOS/tvOS SDKs and time to
build SDL_image/SDL_mixer from source - it wasn't attempted further here since it can't be
verified without doing exactly that build.

## Opening the project

```
open Junkbot.xcodeproj
```

Xcode will resolve the local `JunkbotCore` package dependency automatically. You'll be prompted
once to trust `swift-lingo`'s build tool plugin (`LingoTranspilerPlugin`) - approve it, this is
expected and not a security concern specific to this project.
