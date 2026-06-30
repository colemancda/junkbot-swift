// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "Junkbot",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.56.0")
  ],
  targets: [
    .target(
      name: "JunkbotCore"
    ),
    .executableTarget(
      name: "JunkbotApp",
      dependencies: [
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
      ],
      swiftSettings: [
        .unsafeFlags(["-wmo", "-Osize"])
      ]
    ),
  ]
)
