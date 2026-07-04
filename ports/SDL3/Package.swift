// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "JunkbotSDL3Port",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(path: "../.."),
    // Provides the `SDL3Swift` Swift wrapper and (transitively, via its own `CSDL3` target)
    // the raw `CSDL3` C module our code still imports directly for everything the wrapper
    // doesn't cover yet (event polling, gamepad, cursors, texture color-mod/scale-mode/rotated
    // copy, coordinate conversion, ticks - see ports/SDL3/README.md's wrapper-gap notes).
    // `CSDL3` isn't a declared product of this package, but SwiftPM still makes a dependency's
    // system-library targets importable to downstream targets that depend on any product that
    // reaches them in the build graph - verified against SDL3Swift 3.0.0.
    .package(url: "https://github.com/PureSwift/SDL", .upToNextMajor(from: "3.0.0")),
  ],
  targets: [
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
        .product(name: "SDL3Swift", package: "SDL"),
        "CSDL3Image",
        "CSDL3Mixer",
      ]
    ),
  ]
)
