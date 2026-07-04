// swift-tools-version: 6.3
import PackageDescription

// NOTE: this package is a best-effort scaffold, not a verified build - there is no Android
// NDK/Swift Android SDK toolchain in the environment this was authored in. See
// ports/Android/README.md for what's confirmed vs. what still needs testing on real hardware.

let package = Package(
  name: "JunkbotAndroid",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(path: "../.."),
    .package(url: "https://github.com/swift-android-sdk/swift-android-native.git", from: "2.0.0"),
  ],
  targets: [
    // Headers/libs for these three come from the official SDL3*-devel-*-android.zip release
    // assets (libsdl-org/SDL, SDL_image, SDL_mixer releases), extracted under
    // ports/Android/Vendor/ - see README.md for the exact layout expected here. Unlike
    // ports/Linux's CSDL3 (Homebrew/pkgConfig-based), there's no pkg-config on Android, so these
    // rely on explicit header/library search paths set on the consuming target below instead.
    .systemLibrary(name: "CSDL3"),
    .systemLibrary(name: "CSDL3Image"),
    .systemLibrary(name: "CSDL3Mixer"),
    .executableTarget(
      name: "JunkbotSDL3",
      dependencies: [
        .product(name: "JunkbotCore", package: "junkbot-swift"),
        .product(name: "AndroidNative", package: "swift-android-native", condition: .when(platforms: [.android])),
        .product(name: "AndroidFileManager", package: "swift-android-native", condition: .when(platforms: [.android])),
        .product(name: "AndroidContext", package: "swift-android-native", condition: .when(platforms: [.android])),
        "CSDL3",
        "CSDL3Image",
        "CSDL3Mixer",
      ],
      cSettings: [
        .headerSearchPath("../../Vendor/SDL3-android/include"),
        .headerSearchPath("../../Vendor/SDL3_image-android/include"),
        .headerSearchPath("../../Vendor/SDL3_mixer-android/include"),
      ],
      linkerSettings: [
        .unsafeFlags([
          "-L../../Vendor/SDL3-android/lib",
          "-L../../Vendor/SDL3_image-android/lib",
          "-L../../Vendor/SDL3_mixer-android/lib",
        ])
      ]
    ),
  ]
)
