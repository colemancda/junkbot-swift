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

/// Ticks elapsed since the movie started (1 tick = 1/60 sec); updated by the host's game loop.
nonisolated(unsafe) public var currentTicks: Int = 0
/// Milliseconds elapsed since the movie started; updated by the host's game loop.
nonisolated(unsafe) public var currentMilliseconds: Int = 0

/// Stand-in for Lingo's `_global`/`glob` object, used by transpiled scripts for shared state.
nonisolated(unsafe) public let glob = LingoEnvironment.shared.getGlobal("glob")
/// Stand-in for Director's list of active actor (behavior script instance) objects.
nonisolated(unsafe) public var actorList: [LingoObject] = []
/// Stand-in for Lingo's `the runMode` ("Author" or "Runtime").
nonisolated(unsafe) public var runMode: String = "Author"
/// Stand-in for Lingo's `the moviePath`.
nonisolated(unsafe) public var moviePath: String = ""
/// Stand-in for Lingo's `the movieName`.
nonisolated(unsafe) public var movieName: String = ""

// MARK: - Input stubs

/// Stand-in for Lingo's `the mouseDown`; updated by the host's input handling.
nonisolated(unsafe) public var mouseIsDown: Bool = false
/// Stand-in for Lingo's `the mouseLoc`; updated by the host's input handling.
nonisolated(unsafe) public var mouseLoc: Point = Point()
/// Stand-in for Lingo's `keyPressed(key)`. Always returns `false`; wire up to real keyboard state
/// if a transpiled script needs it.
public func keyPressed(_ key: String) -> Bool { false }

// MARK: - Random (replaces Lingo's `random(n)` which returns 1..n inclusive)

/// Stand-in for Lingo's `random(n)`. Currently derived from `currentTicks` rather than a real RNG
/// — replace with a seeded xorshift or platform RNG if a transpiled script's randomness matters.
public func lingoRandom(_ n: Int) -> Int {
  guard n > 0 else { return 0 }
  // Platform must seed this; replace with a seeded xorshift or platform RNG
  return (n > 1) ? (1 + (currentTicks % n)) : 1
}

// MARK: - Sound

// MARK: - Navigation

/// Stand-in for Lingo's `go to frame "scene"`. No-op.
public func go(_ scene: String) {}
/// Stand-in for Lingo's `go to frame n`. No-op.
public func go(_ frame: Int) {}
/// Stand-in for Lingo's `the frameLabel`.
nonisolated(unsafe) public var theFrameLabel: String = ""

// MARK: - Cursor

/// Stand-in for Lingo's `cursor`. No-op.
public func setCursor(_ cursor: String) {}

// MARK: - Director messaging stubs

/// Stand-in for Lingo's `sendAllSprites(#msg)`. No-op.
public func sendAllSprites(_ msg: String) {}
/// Stand-in for Lingo's `sendAllSprites(#msg, arg)`. No-op.
public func sendAllSprites(_ msg: String, _ arg: LingoValue) {}
/// Stand-in for Lingo's `nothing` (used as a deliberate no-op statement). No-op.
public func nothing() {}
/// Stand-in for Lingo's `updateStage()`. No-op (this port has no separate Stage buffer to flip).
public func updateStage() {}
/// Stand-in for Lingo's `the externalParamValue`. Always returns `.void`.
public func externalParamValue(_ name: String) -> LingoValue { .void }
/// Stand-in for Lingo's `getPref(name)`. Always returns an empty string.
public func getPref(_ pref: String) -> String { "" }
/// Stand-in for Lingo's `setPref(name, value)`. No-op.
public func setPref(_ pref: String, _ val: String) {}
/// Stand-in for Lingo's `frameReady(frame, marker)`. Always returns `true`.
public func frameReady(_ frame: Int = 1, marker: String = "") -> Bool { true }
/// Stand-in for Lingo's `frameReady()`. Always returns `true`.
public func frameReady() -> Bool { true }

// MARK: - Network stubs

/// Stand-in for Lingo's `postNetText(url, params)`. Always returns `.void`.
public func postNetText(_ url: String, _ params: LingoPropertyListClass) -> LingoValue { .void }
/// Stand-in for Lingo's `getStreamStatus(url)`. Always returns an empty property list.
public func getStreamStatus(_ url: String) -> LingoPropertyListClass { .init(.init()) }
/// Stand-in for Lingo's `tellStreamStatus(status)`. No-op.
public func tellStreamStatus(_ status: Int) {}

/// Stand-in for Lingo's `the netConnected`/similar internet-connectivity check. Always returns `false`.
public func isInternetConnected() -> Bool { false }
/// Stand-in for Lingo's `alert(msg)`. No-op.
public func alert(_ msg: String) {}
/// Stand-in for Lingo's `gotoNetPage(url)`. No-op.
public func goToNetPage(_ url: LingoValue) {}
/// Stand-in for Lingo's `the selection` (text-field selection).
nonisolated(unsafe) public var selection: String = ""
/// Stand-in for Lingo's `pass` statement (propagate an event to the next handler in the chain). No-op.
public func pass() {}

// MARK: - Cast/member stubs

/// Stand-in for Lingo's `SndSFX(soundName)`. No-op.
public func SndSFX(_ soundName: String) {
  }
/// Stand-in for Lingo's `the number of members of castLib`. Always returns `0`.
public func numberOfCastMembers(inCastLib: String) -> Int { 0 }
/// Stand-in for Lingo's `member(n, castLib)`. Always returns `nil`.
public func member(_ n: Int, _ castLib: String) -> LingoMember? { nil }
/// Stand-in for Lingo's `the mouseLine` (text-field line under the pointer).
nonisolated(unsafe) public var mouseLine: Int = 0
/// Stand-in for Lingo's `netDone(id)`. Always returns `false`.
public func netDone(_ id: LingoValue) -> Bool { false }
/// Stand-in for Lingo's `netTextResult(id)`. Always returns an empty string.
public func netTextResult(_ id: LingoValue) -> String { "" }
/// Stand-in for Lingo's `preloadNetThing(url)`. No-op.
public func preloadNetThing(_ url: String) {}
/// Stand-in for Lingo's `netError(id)`. Always returns `.void`.
public func netError(_ id: LingoValue) -> LingoValue { .void }

// MARK: - Member / Sprite stubs (Director rendering API)

/// Stand-in for a Director cast member (text field, bitmap, etc.). Transpiled scripts read/write
/// these properties; this port doesn't back them with real cast data or rendering.
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
  /// Lingo's idiom for downcasting a generic object reference to a member (`x.member`-style
  /// access); since `self` already is a `LingoMember`, this just returns `self`.
  public var asMember: LingoMember? { self }
}

/// Stand-in for a Director sprite (a `LingoMember` placed on the Stage at a channel/location).
/// Transpiled scripts read/write these properties; this port doesn't back them with real rendering.
public class LingoSprite: LingoObject, @unchecked Sendable {
  public var member: LingoMember? = nil
  public var loc: Point = Point()
  /// Horizontal component of `loc` (Lingo's `sprite(n).locH`).
  public var locH: Int {
    get { loc.x }
    set { loc.x = newValue }
  }
  /// Vertical component of `loc` (Lingo's `sprite(n).locV`).
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
  /// Stand-in for Lingo's `sprite(n).updateProp()`. No-op.
  public func updateProp() {}
  /// Stand-in for Lingo's `sprite(n).play()` (e.g. play a digital video/flash member). No-op.
  public func play() {}
  /// Stand-in for Lingo's `sprite(n).gotoFrame(frame)`. No-op.
  public func gotoFrame(_ frame: Int) {}
  /// Stand-in for Lingo's `sprite(n).pageP(dir)`. Always returns `0`.
  public func pageP(_ dir: String) -> Int { 0 }
  /// Stand-in for Lingo's `sprite(n).page(dir)`. No-op.
  public func page(_ dir: String) {}
  public override init() { super.init() }
  /// Lingo's idiom for downcasting a generic object reference to a sprite; since `self` already
  /// is a `LingoSprite`, this just returns `self`.
  public var asSprite: LingoSprite? { self }
}

/// Lingo alias for `LingoSprite`.
public typealias Sprite = LingoSprite
/// Lingo alias for `LingoMember`.
public typealias Member = LingoMember

/// Stand-in for Lingo's `sprite(n)`. Always returns a fresh, empty sprite.
public func sprite(_ n: Int) -> LingoSprite { LingoSprite() }
/// Stand-in for Lingo's `member("name")`. Always returns `nil`.
public func member(_ name: String) -> LingoMember? { nil }
/// Stand-in for Lingo's `member("name", castLib)`. Always returns a fresh, empty member.
public func member(_ name: String, _ castLib: String) -> LingoMember { LingoMember() }
/// Stand-in for Lingo's `member(n)`. Always returns a fresh, empty member.
public func member(_ n: Int) -> LingoMember { LingoMember() }
/// Stand-in for Lingo's `member(n, castLib)`. Always returns a fresh, empty member.
public func member(_ n: Int, _ castLib: String) -> LingoMember { LingoMember() }

/// Stand-in for Lingo's `rgb(r, g, b)` color constructor. Always returns `.void`.
public func rgb(_ r: Int, _ g: Int, _ b: Int) -> LingoValue { .void }

// MARK: - Debug

/// Stand-in for a debug print statement used by transpiled scripts. No-op.
public func debugLog(_ s: String) {}
/// Stand-in for Lingo's `the frame` (current frame number).
nonisolated(unsafe) public var theFrame: Int = 1

/// Stand-in for Lingo's `field("name")` (a field cast member's text). Reads `member(name)?.text`.
public func field(_ name: String) -> String { member(name)?.text ?? "" }

/// Stand-in for Lingo's `the frame` (alternate global some transpiled scripts reference directly).
nonisolated(unsafe) public var frame: Int = 1
/// Stand-in for Lingo's `marker(label)` (frame index of a named marker). Always returns `0`.
public func marker(_ label: String) -> Int { 0 }
