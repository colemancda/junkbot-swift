// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "Junkbot",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "JunkbotCore", targets: ["JunkbotCore"])
  ],
  dependencies: [
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
    .testTarget(
      name: "JunkbotCoreTests",
      dependencies: ["JunkbotCore"]
    ),
  ]
)
