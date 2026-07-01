// DirectorStubs.swift
//
// Adobe Director/Lingo compatibility shims required by the auto-generated, transpiled Lingo
// behavior scripts (see the `Internal`/`catalog`/`dynamic`/`editor`/`loading`/`play`/
// `screens_by_peter` subdirectories) so they compile as plain Swift. These are not part of the
// hand-written game/simulation logic in the rest of JunkbotCore — most are no-op stubs (sound,
// networking, cast-member lookup) standing in for engine/platform features the transpiled scripts
// reference but that this port doesn't need; a few (`currentTicks`, `mouseIsDown`, `lingoRandom`)
// are wired up to real state by the host application's game loop. Replace stubs with real
// implementations only if a transpiled script actually needs the behavior.

import LingoRuntime

// MARK: - Time (replaces `the ticks` and `the milliSeconds`)
nonisolated(unsafe) public var currentTicks: Int = 0  // updated by game loop; 1 tick = 1/60 sec
nonisolated(unsafe) public var currentMilliseconds: Int = 0  // updated by game loop

nonisolated(unsafe) public let glob = LingoEnvironment.shared.getGlobal("glob")
nonisolated(unsafe) public var actorList: [LingoObject] = []
nonisolated(unsafe) public var runMode: String = "Author"
nonisolated(unsafe) public var moviePath: String = ""
nonisolated(unsafe) public var movieName: String = ""

// MARK: - Input stubs
nonisolated(unsafe) public var mouseIsDown: Bool = false
nonisolated(unsafe) public var mouseLoc: Point = Point()
public func keyPressed(_ key: String) -> Bool { false }

// MARK: - Random (replaces Lingo's `random(n)` which returns 1..n inclusive)
public func lingoRandom(_ n: Int) -> Int {
  guard n > 0 else { return 0 }
  // Platform must seed this; replace with a seeded xorshift or platform RNG
  return (n > 1) ? (1 + (currentTicks % n)) : 1
}

// MARK: - Sound

// MARK: - Navigation
public func go(_ scene: String) {}
public func go(_ frame: Int) {}
nonisolated(unsafe) public var theFrameLabel: String = ""

// MARK: - Cursor
public func setCursor(_ cursor: String) {}

// MARK: - Director messaging stubs
public func sendAllSprites(_ msg: String) {}
public func sendAllSprites(_ msg: String, _ arg: LingoValue) {}
public func nothing() {}
public func updateStage() {}
public func externalParamValue(_ name: String) -> LingoValue { .void }
public func getPref(_ pref: String) -> String { "" }
public func setPref(_ pref: String, _ val: String) {}
public func frameReady(_ frame: Int = 1, marker: String = "") -> Bool { true }
public func frameReady() -> Bool { true }

// MARK: - Network stubs
public func postNetText(_ url: String, _ params: LingoPropertyListClass) -> LingoValue { .void }
public func getStreamStatus(_ url: String) -> LingoPropertyListClass { .init(.init()) }
public func tellStreamStatus(_ status: Int) {}

public func isInternetConnected() -> Bool { false }
public func alert(_ msg: String) {}
public func goToNetPage(_ url: LingoValue) {}
nonisolated(unsafe) public var selection: String = ""
public func pass() {}
// MARK: - Cast/member stubs

public func SndSFX(_ soundName: String) {
  }
public func numberOfCastMembers(inCastLib: String) -> Int { 0 }
public func member(_ n: Int, _ castLib: String) -> LingoMember? { nil }
nonisolated(unsafe) public var mouseLine: Int = 0
public func netDone(_ id: LingoValue) -> Bool { false }
public func netTextResult(_ id: LingoValue) -> String { "" }
public func preloadNetThing(_ url: String) {}
public func netError(_ id: LingoValue) -> LingoValue { .void }

// MARK: - Member / Sprite stubs (Director rendering API)
public class LingoMember: LingoObject, @unchecked Sendable {
  public var text: String = ""
  public var name: String = ""
  public var width: Int = 0
  public var height: Int = 0
  public var image: LingoValue = .void
  public var regPoint: Point = Point()
  public var rect: LingoValue = .void
  public var hilite: Bool = false
  public var editable: Bool = false
  public var bgColor: LingoValue = .void
  public override init() { super.init() }
  public var asMember: LingoMember? { self }
}

public class LingoSprite: LingoObject, @unchecked Sendable {
  public var member: LingoMember? = nil
  public var loc: Point = Point()
  public var locH: Int {
    get { loc.x }
    set { loc.x = newValue }
  }
  public var locV: Int {
    get { loc.y }
    set { loc.y = newValue }
  }
  public var locZ: Int = 0
  public var visible: Bool = true
  public var puppet: Bool = false
  public var blend: Int = 100
  public var width: Int = 0
  public var height: Int = 0
  public var ink: Int = 0
  public var rect: LingoValue = .void
  public var color: LingoValue = .void
  public var bgColor: LingoValue = .void
  public var scriptInstanceList: [LingoObject] = []
  public func updateProp() {}
  public func play() {}
  public func gotoFrame(_ frame: Int) {}
  public func pageP(_ dir: String) -> Int { 0 }
  public func page(_ dir: String) {}
  public override init() { super.init() }
  public var asSprite: LingoSprite? { self }
}

public typealias Sprite = LingoSprite
public typealias Member = LingoMember

public func sprite(_ n: Int) -> LingoSprite { LingoSprite() }
public func member(_ name: String) -> LingoMember? { nil }
public func member(_ name: String, _ castLib: String) -> LingoMember { LingoMember() }
public func member(_ n: Int) -> LingoMember { LingoMember() }
public func member(_ n: Int, _ castLib: String) -> LingoMember { LingoMember() }

public func rgb(_ r: Int, _ g: Int, _ b: Int) -> LingoValue { .void }

// MARK: - Debug
public func debugLog(_ s: String) {}
nonisolated(unsafe) public var theFrame: Int = 1

public func field(_ name: String) -> String { member(name)?.text ?? "" }

nonisolated(unsafe) public var frame: Int = 1
public func marker(_ label: String) -> Int { 0 }
