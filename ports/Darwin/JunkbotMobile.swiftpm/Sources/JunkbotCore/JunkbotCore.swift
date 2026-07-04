/// `JunkbotCore` is the platform-independent core of the Junkbot game engine: entity/level data
/// models (`Types.swift`, `Level.swift`), simulation (`GameEngine.swift`, `Simulation.swift`,
/// `Collision.swift`), and level text I/O (`LevelText.swift`, `LevelParse.swift`,
/// `LevelSerialize.swift`). It has no dependency on JavaScriptKit or any browser/DOM API, so it
/// builds both for native platforms (used by `JunkbotCoreTests` and the SDL3-based `JunkbotSDL3`
/// native app) and for the embedded-Swift WASM target consumed by `JunkbotWASM`, which bridges it
/// to the browser.
