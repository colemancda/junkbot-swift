// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "JunkbotSDL2Port",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(path: "../.."),
    // Provides the `SDL2Swift` Swift wrapper and (transitively, via its own `CSDL2` target)
    // the raw `CSDL2` C module our code still imports directly for everything the wrapper
    // doesn't cover yet (event polling, gamepad, cursors, texture color-mod/scale-mode/rotated
    // copy, coordinate conversion, ticks - see ports/SDL2/README.md's wrapper-gap notes).
    // `CSDL2` isn't a declared product of this package, but SwiftPM still makes a dependency's
    // system-library targets importable to downstream targets that depend on any product that
    // reaches them in the build graph - verified against SDL2Swift 3.0.0.
    .package(url: "https://github.com/PureSwift/SDL", .upToNextMajor(from: "3.0.0")),
  ],
  targets: [
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
        .product(name: "SDL2Swift", package: "SDL"),
        "CSDL2Image",
        "CSDL2Mixer",
      ]
    ),
  ]
)
