@_exported import _Concurrency

/// The main actor, which Embedded Swift doesn't have.
///
/// Everything here runs on the main thread, so this global actor only gives
/// `@MainActor` code, such as SpriteKit scenes and the game's `@GameActor`
/// state, the isolation it expects.
@globalActor
public final actor MainActor {

    public static let shared = MainActor()

    /// Runs `operation` as main actor code. Only call it on the main thread.
    public static func assumeIsolated<T>(_ operation: @MainActor () -> T) -> T {
        withoutActuallyEscaping(operation) { operation in
            unsafeBitCast(operation, to: (() -> T).self)()
        }
    }
}
