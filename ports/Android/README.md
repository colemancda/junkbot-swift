# Junkbot Android port

A working Android build: cross-compiled Swift (`JunkbotCore` + the SDL3 game code shared with
`ports/SDL3`) linked into a shared library, loaded by a Java `SDLActivity` shell. Verified
end-to-end on an `android-36 google_apis_playstore arm64-v8a` emulator - title screen, level
loading, sprite rendering, and touch input all work.

## Layout

- `Package.swift` - depends on the root `junkbot-swift` package, `PureSwift/SDL` (the same SDL3
  Swift wrapper `ports/SDL3` uses), and `swift-android-sdk/swift-android-native` (JNI/Context/
  AssetManager/logging bindings for Android). Two targets:
  - `JunkbotGame` - the exact same sources as `ports/SDL3`'s `JunkbotSDL3` executable
    (`Sources/JunkbotSDL3` is a symlink to `../SDL3/Sources/JunkbotSDL3`), minus `main.swift`
    (library targets can't have top-level code).
  - `JunkbotAndroid` (`.library(type: .dynamic)`) - `Sources/JunkbotAndroid/AndroidMain.swift`,
    the Android-specific entry point: a `JNI_OnLoad` that bootstraps the JVM handle Swift's JNI
    core needs, and an `SDL_main` that extracts the APK's bundled game assets to internal storage
    (see below) then calls the shared `junkbotMain()`.
- `Vendor/` (gitignored, populated by `scripts/fetch-sdl.sh`) - the official prebuilt Android SDL3
  libraries (headers, per-ABI `.so`s, pkg-config files, and SDL's Java glue jar), extracted from
  libsdl-org's `*-devel-*-android.zip` release assets. Versions match the desktop build's Homebrew
  versions (SDL3 3.4.12, SDL3_image 3.4.4, SDL3_mixer 3.2.4).
- `AndroidApp/` - the Gradle project. `MainActivity.java` extends SDL's own `SDLActivity`
  (from `Vendor/java/SDL3-android.jar`) rather than reimplementing the SDL lifecycle; its
  `getLibraries()` list controls load order (`SDL3`, `SDL3_image`, `SDL3_mixer`,
  `JunkbotAndroid`). `app/build.gradle` stages the repo's `images/`/`font/`/`levels/`/`audio/`
  into `assets/gameassets/**` at build time, plus a generated manifest (see below).
- `scripts/fetch-sdl.sh` - downloads and lays out `Vendor/`.
- `scripts/stage-jnilibs.sh` - copies the built game `.so`, the vendored SDL `.so`s, and their
  transitive Swift-runtime/NDK `.so` dependencies (resolved via `llvm-readelf -d`, not
  hardcoded) into `AndroidApp/app/src/main/jniLibs/<abi>/`.

## Why a one-time asset-extraction step

The game loads levels/sprites/audio through plain `FileManager`/file-path APIs (`IMG_Load`,
`String(contentsOf:)`, directory scans) - none of which can read files packed inside an APK's
`assets/` (that requires the NDK `AAssetManager` API instead). Rather than rewriting every asset
access in shared, cross-platform game code, `AndroidMain.swift` extracts the bundled
`assets/gameassets/**` tree to internal storage once (~8 MB, well under a second) and points
`repoRoot` at that extracted copy via `assetRootOverridePath`. `app/build.gradle` also generates
`assets/gameassets.manifest` (`path<TAB>bytes` per line) since Android's `AAssetDir` API can't
enumerate subdirectories; its content hash doubles as the "already extracted, and nothing
changed" stamp so relaunches skip straight to the game.

## Build

Prerequisites: the Swift Android SDK (`swift sdk list` should show a `*_android` entry - see
https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html), an
Android NDK r27+ (`~/Library/Android/sdk/ndk/<version>`), and an Android SDK + JDK for Gradle.

```sh
make vendor   # once: downloads Vendor/ (SDL3/SDL3_image/SDL3_mixer Android prebuilts)
make apk      # cross-compiles + stages jniLibs + gradle assembleDebug
make install  # adb install + launch on the connected device/emulator
```

(Or from the repo root: `make android`, after the one-time `make -C ports/Android vendor`.)

Cross-compiles for `arm64-v8a` by default; pass `ABI=x86_64` for Intel-hosted emulators.
`Makefile` auto-detects the NDK under `~/Library/Android/sdk/ndk` and points the Swift Android
SDK's own setup script at it if `ndk-sysroot` hasn't been linked yet. Gradle is run under Android
Studio's bundled JDK when present (`/Applications/Android Studio.app/.../jbr`) - AGP's
jlink-based `android.jar` transform doesn't get along with very new JDKs (e.g. Homebrew's
OpenJDK 26).

## Known gaps

- Only `arm64-v8a`/`x86_64` are wired up (real devices and the common Intel-hosted emulator
  case); `armeabi-v7a` isn't (the Swift Android SDK doesn't ship a 32-bit ARM stdlib).
- No release/signing config - `make apk`/`make install` only produce/install the debug build.
- Gamepad support (`ports/SDL3`'s `GamepadState`) hasn't been exercised on a real Android
  controller, only on-screen touch input.
