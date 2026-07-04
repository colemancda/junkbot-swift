#if os(Android)
import AndroidLooper

/// The global actor every shared game-loop file (`Screens.swift`/`GameRender.swift`/
/// `GameInput.swift`/`MenuFocus.swift`, symlinked across every port) is isolated to.
///
/// On every platform except Android, this is just the real `MainActor` - these ports' game loops
/// already run on the process's actual main thread, so `@MainActor` alone would be enough (as it
/// used to be, before Android existed). Android is the exception: SDL's `SDLActivity` always runs
/// `SDL_main` on its own dedicated pthread, never the process's real main thread (which stays busy
/// servicing the JVM/UI Looper), and Swift Concurrency's real `MainActor` executor on Linux/Android
/// is hard-bound to libdispatch's literal "com.apple.main-thread" queue - touching `@MainActor`
/// state from any other thread trips a `dispatch_assert_queue` runtime trap
/// (`BUG IN CLIENT OF LIBDISPATCH`), not just a compile-time isolation error.
///
/// `AndroidMainActor` (from `swift-android-native`'s `AndroidLooper` module) solves this properly
/// instead of papering over it with `nonisolated(unsafe)`: it's a real, independent global actor
/// backed by an `ALooper`-driven executor that can be installed on *any* thread (see
/// `ports/Android/Sources/JunkbotAndroid/AndroidMain.swift`, which installs it on the SDL thread
/// before ever touching `@GameActor` state) - so `@GameActor`-isolated code gets the same
/// single-writer, dynamically-checked isolation guarantee on Android that `@MainActor` gives every
/// other port, just anchored to the thread that's actually running the game loop there.
public typealias GameActor = AndroidMainActor
#else
public typealias GameActor = MainActor
#endif
