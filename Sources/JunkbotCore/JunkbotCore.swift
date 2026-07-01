/// `JunkbotCore` is the platform-independent core of the Junkbot game engine: entity/level data
/// models (`Types.swift`, `Level.swift`), simulation (`GameEngine.swift`, `Simulation.swift`,
/// `Collision.swift`), and level text I/O (`LevelText.swift`, `LevelParse.swift`,
/// `LevelSerialize.swift`). It has no dependency on JavaScriptKit or any browser/DOM API, so it
/// builds both for native platforms (used by `JunkbotCoreTests`) and for the embedded-Swift WASM
/// target consumed by `JunkbotApp`, which bridges it to the browser.
///
/// The `Internal`/`catalog`/`dynamic`/`editor`/`loading`/`play`/`screens_by_peter` subdirectories
/// and `DirectorStubs.swift` are auto-generated/scaffolding for the Lingo-to-Swift transpiler
/// (`LingoTranspilerPlugin`, from the `swift-lingo` dependency) and are not part of the hand-written
/// game logic described above.
import LingoRuntime
