// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "JunkbotSDL3Port",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(path: "../.."),
    // 3.1.0 added `SDLEvent`/`SDLGamepad`/`SDLCursor` plus `SDL3Image`/`SDL3Mixer` products (SDL_image/
    // SDL_mixer wrappers) - this project uses the Swift wrapper types throughout instead of
    // raw `SDL_*`/`IMG_*`/`MIX_*` calls.
    .package(url: "https://github.com/PureSwift/SDL", .upToNextMajor(from: "3.1.0")),
  ],
  targets: [
    .executableTarget(
      name: "JunkbotSDL3",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift"),
        .product(name: "SDL3Swift", package: "SDL"),
        .product(name: "SDL3Image", package: "SDL"),
        .product(name: "SDL3Mixer", package: "SDL"),
      ]
    ),
  ]
)
