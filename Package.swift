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
      name: "JunkbotWASM",
      dependencies: [
        "JunkbotCore",
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
      ],
      swiftSettings: [
        .unsafeFlags(["-wmo", "-Osize"], .when(platforms: [.wasi])),
        .swiftLanguageMode(.v5),
      ],
    ),
    .systemLibrary(
      name: "CSDL3",
      pkgConfig: "sdl3",
      providers: [.brew(["sdl3"])]
    ),
    .systemLibrary(
      name: "CSDL3Image",
      pkgConfig: "sdl3-image",
      providers: [.brew(["sdl3_image"])]
    ),
    .executableTarget(
      name: "JunkbotSDL3",
      dependencies: [
        "JunkbotCore",
        "CSDL3",
        "CSDL3Image",
      ]
    ),
    .testTarget(
      name: "JunkbotCoreTests",
      dependencies: ["JunkbotCore"]
    ),
  ]
)
