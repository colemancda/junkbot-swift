// swift-tools-version: 6.3
import PackageDescription

// Android build of the SDL3 port. Always cross-compiled with the Swift Android SDK, e.g.:
//
//   swift build --swift-sdk aarch64-unknown-linux-android28 --product JunkbotAndroid -c release
//
// (driven by ports/Android/Makefile, which also points pkg-config at the vendored Android SDL3
// prebuilts under Vendor/ - run scripts/fetch-sdl.sh once first). Unlike the desktop ports this
// produces a *shared library*, not an executable: on Android SDL's Java `SDLActivity` loads
// libJunkbotAndroid.so into the app process and calls its exported `SDL_main` (see
// Sources/JunkbotAndroid/AndroidMain.swift) on a dedicated thread - there is no process `main`.
let package = Package(
  name: "JunkbotAndroid",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "JunkbotAndroid", type: .dynamic, targets: ["JunkbotAndroid"])
  ],
  dependencies: [
    // Explicit `name:` so the identity stays "junkbot-swift" even when the repo checkout
    // directory is named something else (e.g. a git worktree).
    .package(name: "junkbot-swift", path: "../.."),
    // Same SDL3 Swift wrapper the desktop build uses (ports/SDL3). Its CSDL3* system-library
    // targets resolve headers/libs through pkg-config, which the Makefile points at
    // Vendor/lib/<abi>/pkgconfig/ when cross-compiling.
    .package(url: "https://github.com/PureSwift/SDL", .upToNextMajor(from: "3.1.0")),
    // Android NDK niceties: logcat logging, JNI bootstrap, Context + AAssetManager access -
    // used by AndroidMain.swift to extract the APK's bundled game assets to internal storage.
    .package(url: "https://github.com/swift-android-sdk/swift-android-native.git", from: "2.0.0"),
    // Direct dependency (also a transitive one of swift-android-native) so AndroidMain.swift can
    // `import SwiftJavaJNICore` for the `JNI_OnLoad` JVM bootstrap types.
    .package(url: "https://github.com/swiftlang/swift-java-jni-core", from: "0.5.1"),
  ],
  targets: [
    // The exact same sources as ports/SDL3's JunkbotSDL3 executable (Sources/JunkbotSDL3 is a
    // symlink into ../SDL3), minus main.swift's top-level code - library targets can't contain
    // top-level code, and Android's entry point is `SDL_main` below instead.
    .target(
      name: "JunkbotGame",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift"),
        .product(name: "SDL3Swift", package: "SDL"),
        .product(name: "SDL3Image", package: "SDL"),
        .product(name: "SDL3Mixer", package: "SDL"),
      ],
      path: "Sources/JunkbotSDL3",
      exclude: ["main.swift"]
    ),
    .target(
      name: "JunkbotAndroid",
      dependencies: [
        "JunkbotGame",
        .product(name: "SDL3Swift", package: "SDL"),
        .product(name: "AndroidLogging", package: "swift-android-native"),
        .product(name: "AndroidContext", package: "swift-android-native"),
        .product(name: "AndroidFileManager", package: "swift-android-native"),
        .product(name: "SwiftJavaJNICore", package: "swift-java-jni-core"),
      ]
    ),
  ]
)
