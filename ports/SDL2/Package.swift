// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "JunkbotSDL2Port",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(path: "../..")
  ],
  targets: [
    .systemLibrary(
      name: "CSDL2",
      pkgConfig: "sdl2",
      providers: [.brew(["sdl2"])]
    ),
    .systemLibrary(
      name: "CSDL2Image",
      pkgConfig: "SDL2_image",
      providers: [.brew(["sdl2_image"])]
    ),
    .systemLibrary(
      name: "CSDL2Mixer",
      pkgConfig: "SDL2_mixer",
      providers: [.brew(["sdl2_mixer"])]
    ),
    .executableTarget(
      name: "JunkbotSDL2",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift"),
        "CSDL2",
        "CSDL2Image",
        "CSDL2Mixer",
      ]
    ),
  ]
)
