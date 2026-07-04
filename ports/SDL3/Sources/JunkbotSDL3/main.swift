import CSDL3
import SDL3Swift
import SDL3Image
import SDL3Mixer
import Foundation
import JunkbotCore

// MARK: - Repo-relative paths

/// Locates the directory containing `images/`, `font/`, `levels/`, `audio/`. Strategies, tried
/// in order:
/// 1. Apple platforms (macOS/iOS/tvOS, via `ports/Darwin`'s Xcode project): the app bundle's own
///    `Resources` directory - `images/`/`font/`/`levels/`/`audio/` are added as Xcode folder
///    references (preserving their subdirectory structure) so they land there directly under
///    `Bundle.main.resourceURL`, matching how a packaged .app/.ipa actually ships assets.
/// 2. Executable-relative: siblings of the binary itself - this is how a packaged Portmaster
///    port is actually laid out (binary + asset dirs copied into the same folder, see
///    `ports/portmaster/`), and the only one that works once a Linux binary is relocated off
///    this dev machine.
/// 3. Dev-time `#filePath` fallback: this file's own compile-time source path, walked up to the
///    repo root (same trick `Tests/JunkbotCoreTests/LevelTests.swift` uses) - lets `swift run`/
///    `.build/debug/JunkbotSDL3` keep working during development, where the built binary sits
///    under `.build/...`, nowhere near the real asset directories.
let repoRoot: URL = {
  #if canImport(Darwin)
  if let resourceURL = Bundle.main.resourceURL,
    FileManager.default.fileExists(atPath: resourceURL.appendingPathComponent("levels").path)
  {
    return resourceURL
  }
  #endif
  let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
    .resolvingSymlinksInPath()
    .deletingLastPathComponent()
  if FileManager.default.fileExists(
    atPath: executableDirectory.appendingPathComponent("levels").path)
  {
    return executableDirectory
  }
  return URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // main.swift
    .deletingLastPathComponent()  // JunkbotSDL3
    .deletingLastPathComponent()  // Sources
    .deletingLastPathComponent()  // SDL3
    .deletingLastPathComponent()  // ports
}()
let levelsDirectory = repoRoot.appendingPathComponent("levels")
let spritesDirectory = repoRoot.appendingPathComponent("images/sprites")
let spritesUndercoverDirectory = spritesDirectory.appendingPathComponent("Undercover Exclusive")
let backgroundsDirectory = repoRoot.appendingPathComponent("images/backgrounds")
let backgroundsUndercoverDirectory = backgroundsDirectory.appendingPathComponent("Undercover Exclusive")
let audioDirectory = repoRoot.appendingPathComponent("audio/sound-effects")

// MARK: - Level catalog

/// Reads a level `.txt` file as UTF-8, stripping a leading byte-order-mark if present - a few
/// files under `levels/` (e.g. `Terrarium.txt`, `The Garage.txt`) have one, and `String.Encoding
/// .utf8` decoding doesn't strip it automatically, which left a stray `\u{FEFF}` glued to the
/// `[info]` line and broke that file's section parsing entirely (silently, since `Level(text:)`
/// isn't throwing - it would just fail to find `[info]` and produce an all-default/empty `Level`).
func readLevelText(at url: URL) -> String? {
  guard var text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
  if text.hasPrefix("\u{FEFF}") {
    text.removeFirst()
  }
  return text
}

/// Building/basement grouping + listing, shared with any future native target
/// (`Sources/JunkbotCore/LevelCatalog.swift`) - see the Phase 6 plan for why this replaced the
/// old flat `loadLevelSequence`/`levelSequence` auto-play sequencing.
let levelCatalog = LevelCatalog(repoRoot: repoRoot)
guard !(levelCatalog.pagesByGame[.junkbot] ?? []).isEmpty else {
  FileHandle.standardError.write(Data("No levels found under \(levelsDirectory.path)\n".utf8))
  exit(1)
}

let gameEngine = GameEngine()
/// World-space camera center/scale, initialized to the level's center on load and then re-centered
/// on Junkbot every frame by `updateCamera()` (a simplified version of JS's `controlViewport`: no
/// margin-based "only pan once near the edge" deadzone or smoothing, just clamp so the camera never
/// shows past the level bounds).
var cameraCenterX: Double = 0
var cameraCenterY: Double = 0
let cameraScale: Double = 1

@MainActor func updateCamera() {
  guard let junkbot = gameEngine.entities.first(where: { $0.type == .junkbot }) else { return }
  var targetX = Double(junkbot.x) + Double(junkbot.width) / 2
  var targetY = Double(junkbot.y) + Double(junkbot.height) / 2

  if let bounds = gameEngine.levelBounds {
    let halfViewWidth = Double(windowWidth) / 2 / cameraScale
    let halfViewHeight = Double(windowHeight) / 2 / cameraScale
    let minX = Double(bounds.x) + halfViewWidth
    let maxX = Double(bounds.x) + Double(bounds.width) - halfViewWidth
    let minY = Double(bounds.y) + halfViewHeight
    let maxY = Double(bounds.y) + Double(bounds.height) - halfViewHeight
    // If the level is narrower/shorter than the window, center on it instead of clamping to a
    // backwards (min > max) range.
    targetX = minX > maxX ? Double(bounds.x) + Double(bounds.width) / 2 : min(max(targetX, minX), maxX)
    targetY = minY > maxY ? Double(bounds.y) + Double(bounds.height) / 2 : min(max(targetY, minY), maxY)
  }

  cameraCenterX = targetX
  cameraCenterY = targetY
}

// MARK: - SDL setup

do {
  try SDL.initialize(subSystems: [.video, .audio, .gamepad])
} catch {
  FileHandle.standardError.write(Data("SDL.initialize failed: \(error)\n".utf8))
  exit(1)
}
defer { SDL.quit() }

// Load the title screen level before creating the window, so the window's default size can
// match its actual bounds (no letterboxing on startup) instead of an arbitrary fixed guess. The
// window stays resizable afterward for levels of other sizes (see `.windowResized` below).
gameEngine.loadLevel(fromText: readLevelText(at: titleScreenLevelURL) ?? "")
var windowWidth: Int32 = gameEngine.levelBounds.map { $0.width } ?? 900
var windowHeight: Int32 = gameEngine.levelBounds.map { $0.height } ?? 675

// Plain top-level `let`s (not `guard let`) so `window`/`renderer` are true module-level symbols
// visible from other files (Screens.swift, TextRenderer.swift, etc.) - a `guard let` binding at
// main.swift's top level only stays in scope for the rest of *this* file.
let window: SDLWindow = {
  do {
    let window = try SDLWindow(
      title: "Junkbot",
      frame: (x: .centered, y: .centered, width: Int(windowWidth), height: Int(windowHeight)),
      // `.highPixelDensity` requests a backing buffer that matches the display's real pixel
      // density (e.g. 2x on Retina) instead of a 1x buffer the OS then has to upscale/blur to
      // fill the screen - without it, everything rendered looks visibly softer than the
      // original (non-Retina-aware) Director/Flash build.
      options: [.resizable, .highPixelDensity])
    // Don't allow shrinking below the default size - `windowWidth`/`windowHeight` are also the
    // fixed logical resolution the integer-scale renderer setup (below) scales up from, so a
    // smaller window would force a sub-1x (fractional/cropped) scale instead of a clean integer one.
    window.setMinimumSize(width: windowWidth, height: windowHeight)
    return window
  } catch {
    FileHandle.standardError.write(Data("SDLWindow init failed: \(error)\n".utf8))
    exit(1)
  }
}()

let renderer: SDLRenderer = {
  do {
    return try SDLRenderer(window: window)
  } catch {
    FileHandle.standardError.write(Data("SDLRenderer init failed: \(error)\n".utf8))
    exit(1)
  }
}()

// With `.highPixelDensity`, the renderer's actual output is in real device pixels (e.g. 2x on
// Retina) while every draw call in this codebase is written in fixed logical units
// (`windowWidth`/`windowHeight`, set once above from the level's own bounds and never resized -
// see `.windowResized` below) - logical presentation makes SDL scale those logical units up to
// the real device-pixel output automatically. `.integerScale` (rather than `.letterbox`/
// `.stretch`) restricts that scaling to whole multiples (1x, 2x, 3x, ...), letterboxing any
// leftover space, so resizing the window never produces a fractional/blurry scale factor.
try? renderer.setLogicalSize(width: windowWidth, height: windowHeight, presentation: .integerScale)

/// The `GameRenderer` every shared drawing file (`Screens.swift`, `TextRenderer.swift`, and this
/// file's own `renderWorld`/`VirtualCursor`) draws through - see `Renderer.swift`.
let gameRenderer: GameRenderer = SDL3Renderer(renderer: renderer)

/// `SDL.ticks`/`SDL.open(url:)` wrapped as plain Swift functions so the shared, symlinked
/// `Screens.swift` can call them without needing to `import SDL3Swift` itself (Swift's `import`
/// is file-scoped, and `ports/SDL2`'s copy of this file imports `SDL2Swift` instead - a shared
/// file can't statically import either one).
func currentTicksNanoseconds() -> UInt64 { SDL.ticks }
func openExternalURL(_ url: String) { try? SDL.open(url: url) }

/// Window-space (point) coordinates, as reported by SDL mouse events, in the current logical
/// presentation's render-space units - the two differ once `.integerScale` presentation
/// introduces letterboxing (render-space (0, 0) may sit inside a black bar rather than the
/// window's actual top-left corner). Every mouse-event handler must convert through this before
/// using a position for hit-testing or world math, since all of that math is written in
/// render-space (`windowWidth`/`windowHeight`) units.
@MainActor func windowToRenderPoint(x: Float, y: Float) -> (x: Float, y: Float) {
  gameRenderer.windowToRender(x: x, y: y)
}

/// The inverse of `windowToRenderPoint` - needed wherever code warps the OS cursor (which takes
/// window-space coordinates) from a render-space position (`lastMouseScreenX/Y`, gamepad
/// stick/d-pad nudge math).
@MainActor func renderToWindowPoint(x: Float, y: Float) -> (x: Float, y: Float) {
  gameRenderer.renderToWindow(x: x, y: y)
}

// MARK: - Audio

/// One shared `SDLMixer` device for both sound effects (`SoundBoard`) and background music
/// (`MusicPlayer`) - built on `SDL3Mixer`'s wrapper around SDL3_mixer's new `MIX_` API (a
/// from-scratch redesign, not the old SDL2-style `Mix_*` API), which decodes both .ogg and .wav
/// via its bundled codecs.
let mixer: SDLMixer? = {
  do {
    try SDL.initializeMixer()
  } catch {
    FileHandle.standardError.write(Data("SDL.initializeMixer failed: \(error)\n".utf8))
    return nil
  }
  do {
    return try SDLMixer()
  } catch {
    FileHandle.standardError.write(Data("SDLMixer init failed: \(error)\n".utf8))
    return nil
  }
}()
defer { SDL.quitMixer() }

/// Sound-effect playback, mirroring `src/game.js`'s `playSound(soundName)` / `hotResourcePaths`.
/// `GameEngine.onPlaySound` is int-keyed (`Types.swift`'s `SoundID`), so this maps id ->
/// repo-relative filename directly instead of going through JS's intermediate string-name
/// indirection.
final class SoundBoard {
  private let mixer: SDLMixer?
  private var audioByID: [Int32: SDLAudio] = [:]

  /// `SoundID.rawValue -> audio/sound-effects/-relative path`, matching `hotResourcePaths` in
  /// src/game.js exactly (including the two win/lose voice lines, ids 19/20 - JS handles those
  /// via its own separate winLoseState watcher instead of this table, but nothing stops us from
  /// covering them the same way as every other sound here).
  private static let paths: [Int32: String] = [
    0: "turn1.ogg",
    1: "blockpickup.ogg",
    2: "blockdrop.ogg",
    3: "blockclick.ogg",
    4: "fall.ogg",
    5: "headbonk1.ogg",
    6: "eat1.ogg",
    7: "garbage1.ogg",
    8: "switch_click.ogg",
    9: "switch_on.ogg",
    10: "switch_off.ogg",
    11: "fire.ogg",
    12: "electricity1.ogg",
    13: "undercover/laser_hit.wav",
    14: "robottouch4.ogg",
    15: "shieldon2.ogg",
    16: "h_powerup1.ogg",
    17: "h_powerdown3.ogg",
    18: "undercover/teleport.wav",
    19: "voice_ohyeah.ogg",
    20: "voice_ouch.ogg",
    21: "voice_uhoh.ogg",
    22: "jump3.ogg",
    23: "fan.ogg",
    24: "drip1.ogg",
    25: "drip2.ogg",
    26: "drip3.ogg",
    27: "lego-creator/undo-I0512.wav",
    // Menu sounds (MenuSoundID in Screens.swift, disjoint from the engine's SoundID range) -
    // buttonClick/tabSwitch/enterLevel in src/game.js's resource paths, matching the Lingo
    // sources' SndSFX("h_button1")/("h_powerup3")/level-start sounds.
    100: "h_button1.ogg",
    101: "h_powerup3.ogg",
    102: "enter_level.wav",
  ]

  init(mixer: SDLMixer?, directory: URL) {
    self.mixer = mixer
    guard let mixer else { return }
    for (id, filename) in Self.paths {
      let url = directory.appendingPathComponent(filename)
      guard let audio = try? SDLAudio(mixer: mixer, contentsOfFile: url.path) else {
        FileHandle.standardError.write(Data("Failed to load sound effect \(url.path)\n".utf8))
        continue
      }
      audioByID[id] = audio
    }
    if audioByID.count < Self.paths.count {
      FileHandle.standardError.write(
        Data("Loaded \(audioByID.count)/\(Self.paths.count) sound effects\n".utf8))
    }
  }

  func play(_ id: Int32) {
    guard let mixer, let audio = audioByID[id] else { return }
    try? mixer.play(audio)
  }
}
let soundBoard = SoundBoard(mixer: mixer, directory: audioDirectory)
gameEngine.onPlaySound = { [soundBoard] id in soundBoard.play(id) }

/// Background music, reconstructing `Sources/JunkbotCore/Internal/movie_Sound Code.ls`'s
/// playlist model (`SndMusicStart`/`SndMusicEnd`/`SndCheckPlaylist`) as closely as the available
/// assets allow: `parent_game manager.ls`'s `SndMusicStart("level" & random(5))` picked one of 5
/// named playlists at random per level, each a Director cast member whose *text* listed which
/// audio members to cycle through - that member text isn't preserved here, but `audio/music/`
/// still has exactly 5 same-prefix track groups (`lego1.*`, `demo_4.*`, `demo_5.*`, `demo_6.*`,
/// `demo6_*`) plus an `intro_1.*` group for the loading/menu screens (`SndMusicStart("intro")`
/// in `parent_download manager.ls`) - strongly suggesting those 5 groups are exactly what
/// "level1".."level5" pointed to. Each group loops a random one of its own tracks forever
/// (re-picking whenever the current one finishes, `update()`) until `stop()`, which - mirroring
/// `SndMusicEnd`'s `member(whichMusic & ".end")` lookup - plays that group's fade-out sting once
/// if it has one.
final class MusicPlayer {
  struct Group {
    let tracks: [String]
    let end: String?
  }

  /// Best-effort reconstruction of the original 5 `"level" & random(5)` playlists - see this
  /// class's doc comment. Not verified against the original Director cast member text (lost).
  static let levelGroups: [Group] = [
    Group(tracks: ["lego1.1.ogg", "lego1.2.ogg", "lego1.3.ogg"], end: "lego1.end.ogg"),
    Group(tracks: ["demo_4.1.ogg", "demo_4.3.ogg", "demo_4.5.ogg", "demo_4.6.ogg"], end: "demo_4.end.ogg"),
    Group(tracks: ["demo_5.1.ogg", "demo_5.2.ogg", "demo_5.7.ogg", "demo_5.8.ogg"], end: "demo_5.end.ogg"),
    Group(tracks: ["demo_6.1.ogg", "demo_6.2.ogg", "demo_6.4.ogg", "demo_6.5.ogg"], end: "demo_6.end.ogg"),
    Group(tracks: ["demo6_3.ogg", "demo6_5.ogg", "demo6_6.ogg"], end: "demo6_end.ogg"),
  ]

  private let mixer: SDLMixer?
  private let directory: URL
  private let track: SDLAudioTrack?
  private var audioByFilename: [String: SDLAudio] = [:]
  private var currentGroup: Group?

  init(mixer: SDLMixer?, directory: URL) {
    self.mixer = mixer
    self.directory = directory
    track = mixer.flatMap { try? SDLAudioTrack(mixer: $0) }
  }

  private func audio(for filename: String) -> SDLAudio? {
    if let cached = audioByFilename[filename] { return cached }
    guard let mixer else { return nil }
    let url = directory.appendingPathComponent(filename)
    guard let audio = try? SDLAudio(mixer: mixer, contentsOfFile: url.path) else {
      FileHandle.standardError.write(Data("Failed to load music track \(url.path)\n".utf8))
      return nil
    }
    audioByFilename[filename] = audio
    return audio
  }

  /// Picks one of `levelGroups` at random and starts looping it - the reconstructed equivalent
  /// of `SndMusicStart("level" & random(5))`.
  func startRandomLevelMusic() {
    currentGroup = Self.levelGroups.randomElement()
    playNextTrack()
  }

  private func playNextTrack() {
    guard let track, let group = currentGroup, let filename = group.tracks.randomElement(),
      let audio = audio(for: filename)
    else { return }
    try? track.setAudio(audio)
    try? track.play()
  }

  /// Call once per frame: whenever the currently-playing track finishes, picks a fresh random
  /// track from the same group so the music loops forever, mirroring `SndCheckPlaylist`'s
  /// multi-deep queue refill (simplified to a single track re-armed on completion instead of a
  /// backing queue, which is inaudibly different for a look-ahead this short).
  func update() {
    guard let track, currentGroup != nil, !track.isPlaying else { return }
    playNextTrack()
  }

  /// Stops the looping playlist, playing the current group's fade-out sting once first if it has
  /// one (`SndMusicEnd`'s `member(whichMusic & ".end")` lookup).
  func stop() {
    guard let track, let group = currentGroup else { return }
    currentGroup = nil
    if let end = group.end, let audio = audio(for: end) {
      try? track.setAudio(audio)
      try? track.play()
    } else {
      try? track.stop()
    }
  }
}
let musicPlayer = MusicPlayer(
  mixer: mixer, directory: repoRoot.appendingPathComponent("audio/music"))

// MARK: - Cursor

/// Loads `images/cursors/cursor-*.png` into `SDLCursor`s (hotspot (8, 8), matching the JS
/// frontend's `url(...) 8 8` CSS cursor declarations) and swaps the OS cursor to match
/// `GameEngine.cursorHint` - the native-window equivalent of `render()`'s
/// `canvas.style.cursor = ...` chain in `src/game.js`.
final class CursorSet {
  private var cursors: [GameEngine.CursorHint: SDLCursor] = [:]
  private var current: GameEngine.CursorHint = .none

  init(cursorsDirectory: URL) {
    let files: [(GameEngine.CursorHint, String)] = [
      (.grabbing, "cursor-grabbing.png"),
      (.grabEither, "cursor-grab-either.png"),
      (.grabUpward, "cursor-grab-upward.png"),
      (.grabDownward, "cursor-grab-downward.png"),
      (.grab, "cursor-grab.png"),
    ]
    for (hint, filename) in files {
      let url = cursorsDirectory.appendingPathComponent(filename)
      guard let surface = try? SDLSurface(contentsOfFile: url.path) else { continue }
      guard let cursor = try? SDLCursor(surface: surface, hotspot: (x: 8, y: 8)) else { continue }
      cursors[hint] = cursor
    }
  }

  func apply(_ hint: GameEngine.CursorHint) {
    guard hint != current else { return }
    current = hint
    // `nil` (no custom cursor loaded for this hint) restores the default cursor automatically.
    SDL.setCursor(cursors[hint])
  }
}
let cursorSet = CursorSet(
  cursorsDirectory: repoRoot.appendingPathComponent("images/cursors"))

// MARK: - Game loop

showTitleScreen()

/// Matches `src/game.js`'s `targetFPS = 18` simulation tick rate (the game's actual logic rate,
/// independent of display refresh rate).
let tickIntervalNanoseconds: UInt64 = 1_000_000_000 / 18
var lastTickTime = SDL.ticks

let gamepadState = GamepadState()
var lastFrameTime = SDL.ticks

var running = true
while running {
  while let event = SDL.pollEvent() {
    switch event {
    case .quit:
      running = false

    case .mouseButtonDown(_, let x, let y, _):
      let downPoint = windowToRenderPoint(x: x, y: y)
      lastMouseScreenX = downPoint.x
      lastMouseScreenY = downPoint.y
      // Clicking dismisses the level-entry toast early (behavior_msgBox_Title.ls's mouseUp).
      if levelToastUntil != nil {
        dismissLevelToast()
        break
      }
      // Menu buttons sit visually on top of the world (the title screen overlays Play/Credits
      // on top of its draggable-bricks scene), so they must be hit-tested first regardless of
      // screen - only fall through to world drag input if nothing was clicked.
      if !handleClick(menuButtons, at: downPoint.x, y: downPoint.y), screenOwnsWorldInput() {
        handleMouseDown(x: downPoint.x, y: downPoint.y)
      }

    case .mouseButtonUp(_, let x, let y, _):
      if screenOwnsWorldInput() {
        let upPoint = windowToRenderPoint(x: x, y: y)
        handleMouseUp(x: upPoint.x, y: upPoint.y)
      }

    case .keyDown(_, let keycode):
      switch keycode {
      case Keycode(rawValue: SDLK_ESCAPE):
        escapePressed()
      case Keycode(rawValue: SDLK_UP):
        directionPressed(dx: 0, dy: -1, menuDelta: -1)
      case Keycode(rawValue: SDLK_DOWN):
        directionPressed(dx: 0, dy: 1, menuDelta: 1)
      case Keycode(rawValue: SDLK_LEFT):
        directionPressed(dx: -1, dy: 0, menuDelta: -1)
      case Keycode(rawValue: SDLK_RIGHT):
        directionPressed(dx: 1, dy: 0, menuDelta: 1)
      case Keycode(rawValue: SDLK_RETURN), Keycode(rawValue: SDLK_SPACE):
        activatePressed()
      default:
        break
      }

    case .keyUp(_, let keycode):
      if keycode == Keycode(rawValue: SDLK_RETURN) || keycode == Keycode(rawValue: SDLK_SPACE) {
        activateReleased()
      }

    case .mouseMotion(_, let x, let y, let which):
      let motionPoint = windowToRenderPoint(x: x, y: y)
      lastMouseScreenX = motionPoint.x
      lastMouseScreenY = motionPoint.y
      // Touch-synthesized mouse events carry `MouseID.touch`. Programmatic warps (gamepad
      // stick/d-pad-nudge) set `suppressNextMouseMotionAsSynthetic` right before warping so this
      // one motion event is consumed without re-triggering anything - those call sites already
      // handled input-kind/cursor-visibility themselves. Any *other* motion is genuine mouse
      // hardware movement and must unconditionally show the cursor and hand hover back to the
      // mouse - this can never be skipped based on `lastPointingInput`, or the cursor can get
      // stuck hidden after gamepad/d-pad use.
      if which == .touch {
        notePointingInput(.touch)
      } else if suppressNextMouseMotionAsSynthetic {
        suppressNextMouseMotionAsSynthetic = false
      } else {
        lastPointingInput = .mouse
        SDL.isCursorVisible = true
        focusedButtonIndex = nil
      }
      if screenOwnsWorldInput() {
        handleMouseMove(x: motionPoint.x, y: motionPoint.y)
      }

    case .fingerDown, .fingerMotion:
      notePointingInput(.touch)

    case .gamepadAdded(let which):
      gamepadState.handleAdded(which)

    case .gamepadRemoved(let which):
      gamepadState.handleRemoved(which)

    case .gamepadButtonDown(_, let button):
      switch button {
      case .south:
        notePointingInput(.gamepad)
        activatePressed()
      case .start:
        escapePressed()
      case .dpadUp:
        directionPressed(dx: 0, dy: -1, menuDelta: -1)
      case .dpadDown:
        directionPressed(dx: 0, dy: 1, menuDelta: 1)
      case .dpadLeft:
        directionPressed(dx: -1, dy: 0, menuDelta: -1)
      case .dpadRight:
        directionPressed(dx: 1, dy: 0, menuDelta: 1)
      default:
        break
      }

    case .gamepadButtonUp(_, let button):
      if button == .south {
        activateReleased()
      }

    case .windowResized:
      // `windowWidth`/`windowHeight` are the fixed logical canvas size set once at startup (see
      // above) and deliberately NOT updated here - `.integerScale` presentation needs a stable
      // logical size to scale up by whole multiples as the window resizes (letterboxing the
      // remainder); if this tracked the window's live size instead, the logical-to-output ratio
      // would always be exactly 1 and "integer scaling" would be a no-op. SDL recomputes the
      // actual integer scale factor and letterbox rect from the new window size automatically on
      // the next present - no explicit action needed here.
      break

    case .unknown:
      break
    }
  }

  let now = SDL.ticks
  gamepadState.pollSticks(deltaSeconds: Float(now - lastFrameTime) / 1_000_000_000)
  lastFrameTime = now
  if let toastUntil = levelToastUntil, now >= toastUntil {
    dismissLevelToast()
  }
  if screenOwnsWorldInput() {
    while now - lastTickTime >= tickIntervalNanoseconds {
      lastTickTime += tickIntervalNanoseconds
      gameEngine.tick()
      if currentScreen == .playing {
        let outcome = gameEngine.winLose()
        if outcome == 1 {
          musicPlayer.stop()
          showLevelWinDialog()
          break
        } else if outcome == 2 {
          musicPlayer.stop()
          showLevelLoseDialog()
          break
        }
      }
    }
  } else {
    lastTickTime = now
  }

  updateCamera()
  if screenOwnsWorldInput() {
    cursorSet.apply(gameEngine.cursorHint(worldX: lastMouseWorldX, worldY: lastMouseWorldY))
  }
  musicPlayer.update()
  render()
  SDL.delay(nanoseconds: 1_000_000)
}
