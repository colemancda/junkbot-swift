// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "JunkbotWeb",
  platforms: [.macOS(.v14)],
  dependencies: [
    // Explicit `name:` so the identity stays "junkbot-swift" even when the repo checkout
    // directory is named something else (e.g. a git worktree).
    .package(name: "junkbot-swift", path: "../.."),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.56.0"),
  ],
  targets: [
    .executableTarget(
      name: "JunkbotWASM",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift"),
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
      ],
      swiftSettings: [
        .unsafeFlags(["-wmo", "-Osize"], .when(platforms: [.wasi])),
        .swiftLanguageMode(.v5),
      ],
    )
  ]
)
