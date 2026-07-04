// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

// An iOS "App Playground" (opens both in Xcode 15+ and the Swift Playgrounds app) - replaces
// the `Junkbot-iOS` Xcode target that used to live in `Junkbot.xcodeproj` (now macOS + tvOS
// only). Shares `GameShell.swift`/`GameScene.swift`/`GameViewController.swift`/
// `SpriteKitRenderer.swift` with the Xcode project via symlinks into `Sources/JunkbotPlayground`
// (the same technique `ports/SDL2` already uses to share files with `ports/SDL3`), and
// `Screens.swift`/`TextRenderer.swift`/`Button.swift`/`Renderer.swift`/`Color.swift`/
// `GameRender.swift`/`GameInput.swift` from `ports/SDL3` the same way the Xcode project's file
// references do. Assets (`images`/`font`/`levels`/`audio`) are symlinked into `Resources/` from
// the repo root, the same single-source-of-truth principle every other port uses.
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
  dependencies: [
    .package(path: "../..")
  ],
  targets: [
    .executableTarget(
      name: "JunkbotPlayground",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift")
      ],
      resources: [
        // Symlinks into the repo-root asset directories (single source of truth, same
        // principle every other port uses) - SwiftPM resource paths can't escape the target
        // directory with `../`, so the symlinks live inside `Sources/JunkbotPlayground` itself.
        .copy("images"),
        .copy("font"),
        .copy("levels"),
        .copy("audio"),
      ]
    )
  ]
)
