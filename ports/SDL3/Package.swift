// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "JunkbotSDL3Port",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(path: "../..")
  ],
  targets: [
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
    .systemLibrary(
      name: "CSDL3Mixer",
      pkgConfig: "sdl3-mixer",
      providers: [.brew(["sdl3_mixer"])]
    ),
    .executableTarget(
      name: "JunkbotSDL3",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift"),
        "CSDL3",
        "CSDL3Image",
        "CSDL3Mixer",
      ]
    ),
  ]
)
