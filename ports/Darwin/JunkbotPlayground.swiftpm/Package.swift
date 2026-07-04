// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

// An iOS "App Playground" (opens both in Xcode 15+ and the Swift Playgrounds app) - replaces
// the `Junkbot-iOS` Xcode target that used to live in `Junkbot.xcodeproj` (now macOS + tvOS
// only). Shares `GameShell.swift`/`GameScene.swift`/`GameViewController.swift`/
// `SpriteKitRenderer.swift`/`GamepadInput.swift`/`Audio.swift` with the Xcode project via
// symlinks into `Sources/JunkbotPlayground` (the same technique `ports/SDL2` already uses to
// share files with `ports/SDL3`), and `Screens.swift`/`TextRenderer.swift`/`MenuFocus.swift`/
// `GameRender.swift`/`GameInput.swift` from `ports/SDL3` the same way (`Button`/`Renderer`/
// `Color` live in `JunkbotCore` itself now, no file sharing needed for those - see
// `ports/Darwin/README.md`). Assets (`images`/`font`/`levels`) are symlinked from the repo root,
// the same single-source-of-truth principle every other port uses; `audio` is transcoded to
// `.caf` at build time by `TranscodeAudioPlugin` below instead of being bundled raw.
//
// `JunkbotCore` dependency: a local `path:` dependency only resolves when this manifest is
// parsed on a machine that actually has the rest of the repo checked out next to this bundle -
// true when opened via Xcode on a Mac, false in the Swift Playgrounds app on iPad/iPhone (it
// only has this `.swiftpm` bundle itself, sandboxed, with no sibling `ports/`/`Sources/`
// directories to resolve `../..` against). `#if os(macOS)` here checks the platform actually
// *running* this manifest (Xcode's manifest-loader process vs. Swift Playgrounds' own on-device
// one), not the platform being built for - so on macOS this points at the local checkout (edits
// to `Sources/JunkbotCore` show up immediately), while everywhere else it falls back to fetching
// `JunkbotCore` straight from GitHub so the Playground can resolve and build standalone.
// (`#if` can't appear directly inside an array literal in a Package.swift manifest - SwiftPM's
// manifest parser rejects it with "expected expression in container literal" - so this has to
// build the array via a `var`/`.append` instead of a single `dependencies: [...]` literal.)
var dependencies: [Package.Dependency] = []
#if os(macOS)
dependencies.append(.package(path: "../.."))
#else
dependencies.append(.package(url: "https://github.com/colemancda/junkbot-swift.git", branch: "main"))
#endif

let package = Package(
  name: "JunkbotPlayground",
  platforms: [.iOS("17.0")],
  products: [
    .iOSApplication(
      name: "JunkbotPlayground",
      targets: ["JunkbotPlayground"],
      displayVersion: "1.0",
      bundleVersion: "1",
      iconAssetName: nil,
      accentColorAssetName: nil,
      supportedDeviceFamilies: [.phone, .pad],
      supportedInterfaceOrientations: [.landscapeLeft, .landscapeRight]
    )
  ],
  dependencies: dependencies,
  targets: [
    .plugin(
      name: "TranscodeAudioPlugin",
      capability: .buildTool()
    ),
    .executableTarget(
      name: "JunkbotPlayground",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift")
      ],
      resources: [
        // Symlinks into the repo-root asset directories (single source of truth, same
        // principle every other port uses) - SwiftPM resource paths can't escape the target
        // directory with `../`, so the symlinks live inside `Sources/JunkbotPlayground` itself.
        // `audio` itself is deliberately NOT listed here - almost every file under it is Ogg
        // Vorbis, which `AVAudioPlayer` can't decode, so `TranscodeAudioPlugin` (below) transcodes
        // it to `.caf` at build time instead of bundling the raw source files.
        .copy("images"),
        .copy("font"),
        .copy("levels"),
      ],
      plugins: ["TranscodeAudioPlugin"]
    )
  ]
)
