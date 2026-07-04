# Junkbot Android port — scaffold, not a verified build

This directory was authored without access to an Android NDK / Swift Android SDK toolchain, so
**nothing here has been compiled or run**. Treat it as a starting point, not a working build.
Everything below is either confirmed against real sources (the `swift-android-native` package,
the official SDL3 Android release assets) or explicitly flagged as unverified/best-effort.

## Layout

- `Package.swift` — the Swift side. Depends on the root `junkbot-swift` package (for
  `JunkbotCore`) and `swift-android-sdk/swift-android-native` (for `AndroidFileManager`/
  `AndroidContext`/JNI bootstrap — confirmed real, see its README on GitHub).
- `Sources/JunkbotSDL3` — a **symlink** to `../../Linux/Sources/JunkbotSDL3`. This is the same
  Swift source `ports/Linux` and `ports/Darwin` use; nothing here duplicates it. It still says
  `import CSDL3`/`CSDL3Image`/`CSDL3Mixer` unchanged — this package just provides its own
  Android-specific versions of those three modules.
- `Sources/CSDL3`, `CSDL3Image`, `CSDL3Mixer` — thin module maps, same pattern as
  `ports/Linux`'s, but pointing at the Android NDK build of SDL3 instead of Homebrew.
- `Vendor/` (not created yet) — where the official prebuilt Android SDL3 libraries go. Download
  `SDL3-devel-<version>-android.zip`, `SDL3_image-devel-<version>-android.zip`,
  `SDL3_mixer-devel-<version>-android.zip` from the respective `libsdl-org` GitHub releases,
  extract each into `Vendor/SDL3-android/`, `Vendor/SDL3_image-android/`, `Vendor/
  SDL3_mixer-android/` respectively. **The exact internal layout of those zips (where `include/`
  and per-ABI `.so` files actually land) was not verified here** — `Package.swift`'s
  `headerSearchPath`/`-L` flags are a best guess and will likely need path corrections once you
  actually unzip them.
- `AndroidApp/` — a minimal Gradle project skeleton (`build.gradle`, `AndroidManifest.xml`, a
  Kotlin `MainActivity`) that loads the compiled Swift `.so` and hands off to SDL. **Not tested.**

## Known, unresolved gap: target type

`JunkbotSDL3` is declared as an `executableTarget` here, matching `ports/Linux`'s shape, for
consistency. **This is very likely wrong for Android specifically.** An Android app needs a
loadable shared library (`.so`, `dlopen`'d by the JVM via `System.loadLibrary`), not a standalone
executable with a `main.swift`-style top-level entry point. Getting this right will likely mean:
- Changing this to `.library(name: "JunkbotSDL3", type: .dynamic, targets: [...])`.
- Adding a real JNI entry point (`@_cdecl("JNI_OnLoad")` or similar) instead of relying on
  `main.swift`'s implicit top-level execution, since library targets don't get that convention.
- Possibly restructuring `main.swift`'s top-level code into an explicit `func run()` called from
  that JNI entry point.

This is exactly the kind of detail that needs a real Android build to get right — don't trust
this scaffold's target-type choice without testing it.

## What to do next

1. Get the Swift Android SDK installed (https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html).
2. Download and extract the three `*-devel-*-android.zip` SDL release assets into `Vendor/` as
   described above; fix up the header/lib paths in `Package.swift` to match their real layout.
3. Attempt `swift build --swift-sdk <android-sdk-id> --product JunkbotSDL3` and work through
   whatever the target-type/JNI-entry-point issue above turns into in practice.
4. Wire the resulting `.so` into `AndroidApp/app/src/main/jniLibs/<abi>/` and get the Gradle
   project actually building/running on a device or emulator.
5. Populate `AndroidApp/app/src/main/assets/` from the repo root's `images/`/`font/`/`levels/`/
   `audio/` directories (a Gradle copy task, not done here) and wire `JunkbotCore`'s asset
   loading through `AndroidFileManager`'s `AssetManager.open`/`openDirectory` for those paths
   instead of plain `FileManager`/`IMG_Load(path:)` (which can't reach APK-bundled assets) — this
   was designed in an earlier planning pass but not yet implemented in `JunkbotCore`.
