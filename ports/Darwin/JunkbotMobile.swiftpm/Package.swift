// swift-tools-version: 6.0
import PackageDescription
import AppleProductTypes

// An iOS "App Playground" (opens both in Xcode 15+ and the Swift Playgrounds app) - replaces
// the `Junkbot-iOS` Xcode target that used to live in `Junkbot.xcodeproj` (now macOS + tvOS
// only). Shares `GameShell.swift`/`GameScene.swift`/`GameViewController.swift`/
// `SpriteKitRenderer.swift`/`GamepadInput.swift`/`Audio.swift` with the Xcode project via
// symlinks into `Sources/JunkbotMobile` (the same technique `ports/SDL2` already uses to
// share files with `ports/SDL3`), and `Screens.swift`/`TextRenderer.swift`/`MenuFocus.swift`/
// `GameRender.swift`/`GameInput.swift` from `ports/SDL3` the same way. Assets (`images`/`font`/
// `levels`) are symlinked from the repo root, the same single-source-of-truth principle every
// other port uses. `audio` is the one exception: it's mostly Ogg Vorbis, which `AVAudioPlayer`
// can't decode, so it needs transcoding to `.caf` first - this used to happen at build time via
// a `TranscodeAudioPlugin` build-tool plugin, but SwiftPM always runs plugins sandboxed with no
// opt-out, and `afconvert` cannot decode Ogg Vorbis from inside that sandbox (confirmed: the
// exact same `afconvert -f caff -d LEI16@44100` command that works fine unsandboxed - and via
// Xcode's own Run Script build phases for the macOS/tvOS targets, which aren't plugin-sandboxed -
// fails with "Couldn't open input file" when invoked from a plugin's subprocess). So the plugin's
// gone; `TranscodedAudio/` below is instead transcoded once manually
// (`Scripts/transcode-audio.sh ../../audio/sound-effects
// Sources/JunkbotMobile/TranscodedAudio/sound-effects`, same for `music`) and checked in as
// real files - the one asset directory that isn't a symlinked, single-source-of-truth passthrough,
// since re-running that script is a manual step whenever `audio/` changes, not automatic.
//
// `JunkbotCore`: a plain local target here (`Sources/JunkbotCore`), symlinked in its entirety to
// the repo root's `Sources/JunkbotCore` - not a separate package product. This replaces an
// earlier approach that depended on `JunkbotCore` as an external package (a local `path:`
// dependency on macOS, falling back to `.package(url: "https://github.com/colemancda/
// junkbot-swift.git", from: "0.1.0")` everywhere else, since Swift Playgrounds on iPad/iPhone
// only has this `.swiftpm` bundle itself with no sibling `ports/`/`Sources/` directories a
// `path:` dependency could resolve against). That approach had a real, confirmed-in-practice
// failure mode: resolving `junkbot-swift` as a remote package means fetching a *tagged release*
// and parsing *that tag's* `Package.swift`, whose declared `swift-tools-version` Swift
// Playgrounds' bundled toolchain might not support (confirmed: existing tags declared 6.3, and
// Swift Playgrounds on a real device failed to resolve dependencies at all with "incompatible
// tools version"). A local target has no separate manifest to parse at all, sidestepping that
// entirely - the only remaining requirement is that this `.swiftpm` bundle is opened from
// *within* a full clone of the repo (so the symlink target actually resolves), which is exactly
// how this was being opened on-device already (via a git-backed Files.app file provider), not
// downloaded as a standalone bundle in isolation.
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
  targets: [
    .target(
      name: "JunkbotCore",
      swiftSettings: [
        .enableUpcomingFeature("ApproachableConcurrency")
      ]
    ),
    .executableTarget(
      name: "JunkbotMobile",
      dependencies: [
        "JunkbotCore"
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
