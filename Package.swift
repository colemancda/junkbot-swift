// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "Junkbot",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.56.0"),
    .package(url: "https://github.com/MillerTechnologyPeru/swift-lingo.git", branch: "master"),
  ],
  targets: [
    .target(
      name: "JunkbotCore",
      dependencies: [
        .product(name: "LingoRuntime", package: "swift-lingo")
      ],
      swiftSettings: [
        .enableUpcomingFeature("ApproachableConcurrency")
      ],
      plugins: [
        .plugin(name: "LingoTranspilerPlugin", package: "swift-lingo")
      ]
    ),
    .executableTarget(
      name: "JunkbotApp",
      dependencies: [
        "JunkbotCore",
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
      ],
      swiftSettings: [
        .unsafeFlags(["-wmo", "-Osize"]),
        .swiftLanguageMode(.v5),
      ],
    ),
    .testTarget(
      name: "JunkbotCoreTests",
      dependencies: ["JunkbotCore"]
    ),
  ]
)
