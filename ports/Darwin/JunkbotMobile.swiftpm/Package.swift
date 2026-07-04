// swift-tools-version: 6.0
import PackageDescription
import AppleProductTypes

let package = Package(
  name: "JunkbotMobile",
  platforms: [.iOS("18.0")],
  products: [
    .iOSApplication(
      name: "JunkbotMobile",
      targets: ["JunkbotMobile"],
      bundleIdentifier: "com.colemancda.junkbot",
      teamIdentifier: "4W79SG34MW",
      displayVersion: "1.0",
      bundleVersion: "1",
            appIcon: .placeholder(icon: .cloud),
            accentColor: .presetColor(.orange),
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
        .copy("images"),
        .copy("font"),
        .copy("levels"),
        .copy("TranscodedAudio"),
      ]
    )
  ]
)
