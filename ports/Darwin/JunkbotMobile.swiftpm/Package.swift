// swift-tools-version: 6.0
import PackageDescription
import AppleProductTypes

// An iOS "App Playground" (opens both in Xcode 15+ and the Swift Playgrounds app) - replaces
// the `Junkbot-iOS` Xcode target that used to live in `Junkbot.xcodeproj` (now macOS + tvOS
// only). Shares `GameShell.swift`/`GameScene.swift`/`GameViewController.swift`/
// `SpriteKitRenderer.swift`/`GamepadInput.swift`/`Audio.swift` with the Xcode project via
// symlinks into `Sources/JunkbotMobile` (the same technique `ports/SDL2` already uses to
// share files with `ports/SDL3`), and `Screens.swift`/`TextRenderer.swift`/`MenuFocus.swift`/
// `GameRender.swift`/`GameInput.swift` from `ports/SDL3` the same way (`Button`/`Renderer`/
// `Color` live in `JunkbotCore` itself now, no file sharing needed for those - see
// `ports/Darwin/README.md`). Assets (`images`/`font`/`levels`) are symlinked from the repo root,
// the same single-source-of-truth principle every other port uses. `audio` is the one exception:
// it's mostly Ogg Vorbis, which `AVAudioPlayer` can't decode, so it needs transcoding to `.caf`
// first - this used to happen at build time via a `TranscodeAudioPlugin` build-tool plugin, but
// SwiftPM always runs plugins sandboxed with no opt-out, and `afconvert` cannot decode Ogg Vorbis
// from inside that sandbox (confirmed: the exact same `afconvert -f caff -d LEI16@44100` command
// that works fine unsandboxed - and via Xcode's own Run Script build phases for the macOS/tvOS
// targets, which aren't plugin-sandboxed - fails with "Couldn't open input file" when invoked
// from a plugin's subprocess). So the plugin's gone; `TranscodedAudio/` below is instead
// transcoded once manually (`Scripts/transcode-audio.sh ../../audio/sound-effects
// Sources/JunkbotMobile/TranscodedAudio/sound-effects`, same for `music`) and checked in as
// real files - the one asset directory that isn't a symlinked, single-source-of-truth passthrough,
// since re-running that script is a manual step whenever `audio/` changes, not automatic.
//
// `JunkbotCore` dependency: a local `path:` dependency only resolves when this manifest is
// parsed on a machine that actually has the rest of the repo checked out next to this bundle -
// true when opened via Xcode on a Mac, false in the Swift Playgrounds app on iPad/iPhone (it
// only has this `.swiftpm` bundle itself, sandboxed, with no sibling `ports/`/`Sources/`
// directories to resolve `../..` against). `#if os(macOS)` here checks the platform actually
// *running* this manifest (Xcode's manifest-loader process vs. Swift Playgrounds' own on-device
// one), not the platform being built for - so on macOS this points at the local checkout (edits
// to `Sources/JunkbotCore` show up immediately), while everywhere else it falls back to fetching
// `JunkbotCore` straight from GitHub so JunkbotMobile can resolve and build standalone.
// (`#if` can't appear directly inside an array literal in a Package.swift manifest - SwiftPM's
// manifest parser rejects it with "expected expression in container literal" - so this has to
// build the array via a `var`/`.append` instead of a single `dependencies: [...]` literal.)
var dependencies: [Package.Dependency] = []
#if os(macOS)
dependencies.append(.package(path: "../../.."))
#else
dependencies.append(.package(url: "https://github.com/colemancda/junkbot-swift.git", branch: "main"))
#endif

let package = Package(
  name: "JunkbotMobile",
  platforms: [.iOS("26.0")],
  products: [
    .iOSApplication(
      name: "JunkbotMobile",
      targets: ["JunkbotMobile"],
            bundleIdentifier: "com.colemancda.junkbot",
            teamIdentifier: "4W79SG34MW",
      displayVersion: "1.0",
      bundleVersion: "1",
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .landscapeLeft,
                .landscapeRight
            ],
            appCategory: .puzzleGames
    )
  ],
  dependencies: dependencies,
  targets: [
    .executableTarget(
      name: "JunkbotMobile",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift")
      ],
      resources: [
        // Symlinks into the repo-root asset directories (single source of truth, same
        // principle every other port uses) - SwiftPM resource paths can't escape the target
        // directory with `../`, so the symlinks live inside `Sources/JunkbotMobile` itself.
        .copy("images"),
        .copy("font"),
        .copy("levels"),
        // Manually pre-transcoded `.caf` files, checked in (not a symlink) - see the doc
        // comment above for why this can't be done at build time via a plugin.
        .copy("TranscodedAudio"),
      ]
    )
  ]
)
