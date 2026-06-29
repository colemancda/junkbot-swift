// DirectorStubs.swift
// All Director/platform-specific stubs in one place.
// Replace these with real platform implementations.

// MARK: - Time (replaces `the ticks` and `the milliSeconds`)
public var currentTicks: Int = 0         // updated by game loop; 1 tick = 1/60 sec
public var currentMilliseconds: Int = 0  // updated by game loop

// MARK: - Input stubs
public var mouseIsDown: Bool = false
public var mouseLoc: Point = Point()
public func keyPressed(_ key: String) -> Bool { false }

// MARK: - Random (replaces Lingo's `random(n)` which returns 1..n inclusive)
public func lingoRandom(_ n: Int) -> Int {
    guard n > 0 else { return 0 }
    // Platform must seed this; replace with a seeded xorshift or platform RNG
    return (n > 1) ? (1 + (currentTicks % n)) : 1  // deterministic stub
}

// MARK: - Sound
public func SndSFX(_ name: String) {}
public func SndSFX(_ name: String, _ pan: LV, _ vol: Int) {}
public func SndSFX(_ name: String, sfxpan: Int, sfxlevel: Int = 255, sfxpitch: Int = 0) {}
public func SndMusicStart(_ name: String) {}
public func SndMusicEnd() {}
public func SndCheckPlaylist() {}
public func SndStop() {}
public func SndLevelQueue() {}
public func SNDGetLineCount(_ member: String) -> Int { 0 }

// MARK: - Navigation
public func go(_ scene: String) {}

// MARK: - Cursor
public func setCursor(_ cursor: String) {}
public func setCursorEffect(_ ce: String) {}

// MARK: - Director messaging stubs
public func gbutton(_ msg: String) {}
public func sendAllSprites(_ msg: String) {}
public func sendAllSprites(_ msg: String, _ arg: LV) {}
public func nothing() {}
public func updateStage() {}
public func externalParamValue(_ name: String) -> LV { .void }

// MARK: - Network stubs
public func postNetText(_ url: String, _ params: PropList) -> LV { .void }
public func getNetText(_ url: String) -> LV { .void }
public func netDone(_ id: LV) -> Bool { false }
public func netTextResult(_ id: LV) -> String { "" }
public func preloadNetThing(_ url: String) {}
public func netError(_ id: LV) -> LV { .void }

// MARK: - Member / Sprite stubs (Director rendering API)
public class LingoMember: LingoObject {
    public var text: String = ""
    public var name: String = ""
    public var width: Int = 0
    public var height: Int = 0
    public var image: LV = .void
    public var regPoint: Point = Point()
    public var rect: LV = .void
    public override init() { super.init() }
}

public class LingoSprite: LingoObject {
    public var member: LingoMember = LingoMember()
    public var loc: Point = Point()
    public var locZ: Int = 0
    public var visible: Bool = true
    public var puppet: Bool = false
    public var blend: Int = 100
    public var width: Int = 0
    public var height: Int = 0
    public var ink: Int = 0
    public var rect: LV = .void
    public var scriptInstanceList: [BehaviorBase] = []
    public override init() { super.init() }
}

public func sprite(_ n: Int) -> LingoSprite { LingoSprite() }
public func member(_ name: String) -> LingoMember { LingoMember() }
public func member(_ name: String, _ castLib: String) -> LingoMember { LingoMember() }
public func member(_ n: Int) -> LingoMember { LingoMember() }
public func member(_ n: Int, _ castLib: String) -> LingoMember { LingoMember() }

// MARK: - Debug
public func debugLog(_ s: String) {}
