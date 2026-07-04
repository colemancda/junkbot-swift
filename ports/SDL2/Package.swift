// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "JunkbotSDL2Port",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(path: "../.."),
    // 3.1.0 added `SDLEvent`/`SDLGamepad`/`SDLCursor` plus `SDL2Image`/`SDL2Mixer` products (SDL_image/
    // SDL_mixer wrappers) - this project uses the Swift wrapper types throughout instead of
    // raw `SDL_*`/`IMG_*`/`Mix_*` calls.
    .package(url: "https://github.com/PureSwift/SDL", .upToNextMajor(from: "3.1.0")),
  ],
  targets: [
    .executableTarget(
      name: "JunkbotSDL2",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift"),
        .product(name: "SDL2Swift", package: "SDL"),
        .product(name: "SDL2Image", package: "SDL"),
        .product(name: "SDL2Mixer", package: "SDL"),
      ]
    ),
  ]
)
