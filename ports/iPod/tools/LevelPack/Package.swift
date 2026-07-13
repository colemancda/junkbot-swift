// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LevelPack",
  platforms: [.macOS(.v14)],
  dependencies: [
    // Explicit name: path-based identity is the checkout's directory name,
    // which isn't "junkbot-swift" inside git worktrees.
    .package(name: "junkbot-swift", path: "../../../..")
  ],
  targets: [
    .executableTarget(
      name: "LevelPack",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift")
      ]
    )
  ]
)
