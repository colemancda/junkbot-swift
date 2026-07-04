// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Junkbot",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "JunkbotCore", targets: ["JunkbotCore"])
  ],
  targets: [
    .target(
      name: "JunkbotCore",
      swiftSettings: [
        .enableUpcomingFeature("ApproachableConcurrency")
      ]
    ),
    .testTarget(
      name: "JunkbotCoreTests",
      dependencies: ["JunkbotCore"]
    ),
  ]
)
