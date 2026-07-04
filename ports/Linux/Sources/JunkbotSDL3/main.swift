import CSDL3
import CSDL3Image
import CSDL3Mixer
import Foundation
import JunkbotCore

// MARK: - Repo-relative paths

/// Locates the directory containing `images/`, `font/`, `levels/`, `audio/`. Two strategies,
/// tried in order:
/// 1. Executable-relative: siblings of the binary itself - this is how a packaged Portmaster
///    port is actually laid out (binary + asset dirs copied into the same folder, see
///    `ports/Linux/packaging/`), and the only one that works once the binary is relocated
///    off this dev machine.
/// 2. Dev-time `#filePath` fallback: this file's own compile-time source path, walked up to the
///    repo root (same trick `Tests/JunkbotCoreTests/LevelTests.swift` uses) - lets `swift run`/
///    `.build/debug/JunkbotSDL3` keep working during development, where the built binary sits
///    under `.build/...`, nowhere near the real asset directories.
let repoRoot: URL = {
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
    .deletingLastPathComponent()  // Linux
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

guard SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_GAMEPAD) else {
  FileHandle.standardError.write(Data("SDL_Init failed: \(String(cString: SDL_GetError()))\n".utf8))
  exit(1)
}
defer { SDL_Quit() }

// Load the title screen level before creating the window, so the window's default size can
// match its actual bounds (no letterboxing on startup) instead of an arbitrary fixed guess. The
// window stays resizable afterward for levels of other sizes (see SDL_EVENT_WINDOW_RESIZED below).
gameEngine.loadLevel(fromText: readLevelText(at: titleScreenLevelURL) ?? "")
var windowWidth: Int32 = gameEngine.levelBounds.map { $0.width } ?? 900
var windowHeight: Int32 = gameEngine.levelBounds.map { $0.height } ?? 675
// SDL_WINDOW_RESIZABLE's macro (SDL_UINT64_C(...)) doesn't import into Swift - its raw value
// (SDL_video.h) is 0x0000000000000020. SDL_WINDOW_HIGH_PIXEL_DENSITY (0x2000) requests a
// backing buffer that matches the display's real pixel density (e.g. 2x on Retina) instead of
// a 1x buffer the OS then has to upscale/blur to fill the screen - without it, everything
// rendered looks visibly softer than the original (non-Retina-aware) Director/Flash build.
let windowResizableFlag: SDL_WindowFlags = 0x0000_0000_0000_0020 | 0x0000_0000_0000_2000
// Plain top-level `let`s (not `guard let`) so `window`/`renderer` are true module-level symbols
// visible from other files (Screens.swift, TextRenderer.swift, etc.) - a `guard let` binding at
// main.swift's top level only stays in scope for the rest of *this* file.
let window: OpaquePointer = {
  guard let window = SDL_CreateWindow("Junkbot", windowWidth, windowHeight, windowResizableFlag)
  else {
    FileHandle.standardError.write(Data("SDL_CreateWindow failed: \(String(cString: SDL_GetError()))\n".utf8))
    exit(1)
  }
  // Don't allow shrinking below the default size - `windowWidth`/`windowHeight` are also the
  // fixed logical resolution `SDL_LOGICAL_PRESENTATION_INTEGER_SCALE` scales up from, so a
  // smaller window would force a sub-1x (fractional/cropped) scale instead of a clean integer one.
  _ = SDL_SetWindowMinimumSize(window, windowWidth, windowHeight)
  return window
}()
defer { SDL_DestroyWindow(window) }

let renderer: OpaquePointer = {
  guard let renderer = SDL_CreateRenderer(window, nil) else {
    FileHandle.standardError.write(Data("SDL_CreateRenderer failed: \(String(cString: SDL_GetError()))\n".utf8))
    exit(1)
  }
  return renderer
}()
defer { SDL_DestroyRenderer(renderer) }

// With SDL_WINDOW_HIGH_PIXEL_DENSITY, the renderer's actual output is in real device pixels
// (e.g. 2x on Retina) while every draw call in this codebase is written in fixed logical units
// (`windowWidth`/`windowHeight`, set once above from the level's own bounds and never resized -
// see SDL_EVENT_WINDOW_RESIZED below) - logical presentation makes SDL scale those logical units
// up to the real device-pixel output automatically. INTEGER_SCALE (rather than LETTERBOX/
// STRETCH) restricts that scaling to whole multiples (1x, 2x, 3x, ...), letterboxing any
// leftover space, so resizing the window never produces a fractional/blurry scale factor.
_ = SDL_SetRenderLogicalPresentation(
  renderer, windowWidth, windowHeight, SDL_LOGICAL_PRESENTATION_INTEGER_SCALE)

/// Window-space (point) coordinates, as reported by SDL mouse events, in the current logical
/// presentation's render-space units - the two differ once `SDL_LOGICAL_PRESENTATION_INTEGER_SCALE`
/// introduces letterboxing (render-space (0, 0) may sit inside a black bar rather than the
/// window's actual top-left corner). Every mouse-event handler must convert through this before
/// using a position for hit-testing or world math, since all of that math is written in
/// render-space (`windowWidth`/`windowHeight`) units.
@MainActor func windowToRenderPoint(x: Float, y: Float) -> (x: Float, y: Float) {
  var renderX: Float = 0
  var renderY: Float = 0
  _ = SDL_RenderCoordinatesFromWindow(renderer, x, y, &renderX, &renderY)
  return (renderX, renderY)
}

/// The inverse of `windowToRenderPoint` - needed wherever code warps the OS cursor
/// (`SDL_WarpMouseInWindow` takes window-space coordinates) from a render-space position
/// (`lastMouseScreenX/Y`, gamepad stick/d-pad nudge math).
@MainActor func renderToWindowPoint(x: Float, y: Float) -> (x: Float, y: Float) {
  var windowX: Float = 0
  var windowY: Float = 0
  _ = SDL_RenderCoordinatesToWindow(renderer, x, y, &windowX, &windowY)
  return (windowX, windowY)
}

// MARK: - Sprite loading

/// Texture cache keyed by the generated sprite ID (`Generated/SpriteTable.swift`). Individual
/// per-frame PNGs (rather than the JS frontend's packed spritesheets) are loaded by the ID's
/// atlas name from `images/sprites` / `images/backgrounds` (each with an "Undercover Exclusive"
/// subdirectory) - the individual files share the atlas's exact frame names.
final class TextureCache {
  private var textures: [Int32: UnsafeMutablePointer<SDL_Texture>] = [:]
  private var attemptedAndMissing: Set<Int32> = []
  let renderer: OpaquePointer

  init(renderer: OpaquePointer) {
    self.renderer = renderer
  }

  func texture(for spriteID: Int32) -> UnsafeMutablePointer<SDL_Texture>? {
    if let cached = textures[spriteID] { return cached }
    guard !attemptedAndMissing.contains(spriteID), spriteID >= 0,
      spriteID < spriteNameTable.count
    else { return nil }
    let staticName = spriteNameTable[Int(spriteID)]
    let name = staticName.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
    guard !name.isEmpty else { return nil }

    // The sheet tells us the primary directory, but keep the historical fallback scan too -
    // a few names exist in a different directory than their sheet suggests.
    let directories: [URL]
    switch SpriteSheet(rawValue: spriteSheetTable[Int(spriteID)]) {
    case .backgrounds, .backgroundsUndercover:
      directories = [backgroundsDirectory, backgroundsUndercoverDirectory, spritesDirectory]
    default:
      directories = [spritesDirectory, spritesUndercoverDirectory, backgroundsDirectory]
    }
    for directory in directories {
      let url = directory.appendingPathComponent("\(name).png")
      guard FileManager.default.fileExists(atPath: url.path) else { continue }
      guard let surface = IMG_Load(url.path) else { continue }
      defer { SDL_DestroySurface(surface) }
      guard let texture = SDL_CreateTextureFromSurface(renderer, surface) else { continue }
      // SDL3 defaults new textures to linear filtering, which blurs pixel art whenever a
      // sprite isn't drawn at exact 1:1 scale (i.e. almost always, given camera zoom/offset).
      // The JS canvas path sets `ctx.imageSmoothingEnabled = false` for the same reason.
      _ = SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)
      textures[spriteID] = texture
      return texture
    }
    attemptedAndMissing.insert(spriteID)
    return nil
  }

  deinit {
    for texture in textures.values {
      SDL_DestroyTexture(texture)
    }
  }
}
let textureCache = TextureCache(renderer: renderer)

/// Bitmap-font text rendering for menu UI (title/level-select/win-lose dialogs) - see
/// `TextRenderer.swift`/`Sources/JunkbotCore/Font.swift`.
let textRenderer = TextRenderer(renderer: renderer, fontDirectory: repoRoot.appendingPathComponent("font"))

// MARK: - Audio

/// One shared `MIX_Mixer` device for both sound effects (`SoundBoard`) and background music
/// (`MusicPlayer`) - SDL3_mixer's new "MIX_" API (a from-scratch redesign, not the old
/// SDL2-style `Mix_*` API), which decodes both .ogg and .wav via its bundled codecs.
let mixer: OpaquePointer? = {
  guard MIX_Init() else {
    FileHandle.standardError.write(Data("MIX_Init failed: \(String(cString: SDL_GetError()))\n".utf8))
    return nil
  }
  // SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK's macro (a C cast expression) doesn't import into Swift -
  // its raw value (SDL_audio.h) is 0xFFFFFFFF.
  let defaultPlaybackDevice: SDL_AudioDeviceID = 0xFFFF_FFFF
  guard let mixer = MIX_CreateMixerDevice(defaultPlaybackDevice, nil) else {
    FileHandle.standardError.write(
      Data("MIX_CreateMixerDevice failed: \(String(cString: SDL_GetError()))\n".utf8))
    return nil
  }
  return mixer
}()
defer {
  if let mixer {
    MIX_DestroyMixer(mixer)
  }
  MIX_Quit()
}

/// Sound-effect playback, mirroring `src/game.js`'s `playSound(soundName)` / `hotResourcePaths`.
/// `GameEngine.onPlaySound` is int-keyed (`Types.swift`'s `SoundID`), so this maps id ->
/// repo-relative filename directly instead of going through JS's intermediate string-name
/// indirection.
final class SoundBoard {
  private let mixer: OpaquePointer?
  private var audioByID: [Int32: OpaquePointer] = [:]

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

  init(mixer: OpaquePointer?, directory: URL) {
    self.mixer = mixer
    guard let mixer else { return }
    for (id, filename) in Self.paths {
      let url = directory.appendingPathComponent(filename)
      guard let audio = MIX_LoadAudio(mixer, url.path, false) else {
        FileHandle.standardError.write(
          Data("Failed to load sound effect \(url.path): \(String(cString: SDL_GetError()))\n".utf8)
        )
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
    _ = MIX_PlayAudio(mixer, audio)
  }

  deinit {
    for audio in audioByID.values {
      MIX_DestroyAudio(audio)
    }
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

  private let mixer: OpaquePointer?
  private let directory: URL
  private let track: OpaquePointer?
  private var audioByFilename: [String: OpaquePointer] = [:]
  private var currentGroup: Group?

  init(mixer: OpaquePointer?, directory: URL) {
    self.mixer = mixer
    self.directory = directory
    track = mixer.flatMap { MIX_CreateTrack($0) }
  }

  private func audio(for filename: String) -> OpaquePointer? {
    if let cached = audioByFilename[filename] { return cached }
    guard let mixer else { return nil }
    let url = directory.appendingPathComponent(filename)
    guard let audio = MIX_LoadAudio(mixer, url.path, false) else {
      FileHandle.standardError.write(
        Data("Failed to load music track \(url.path): \(String(cString: SDL_GetError()))\n".utf8))
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
    _ = MIX_SetTrackAudio(track, audio)
    _ = MIX_PlayTrack(track, 0)
  }

  /// Call once per frame: whenever the currently-playing track finishes, picks a fresh random
  /// track from the same group so the music loops forever, mirroring `SndCheckPlaylist`'s
  /// multi-deep queue refill (simplified to a single track re-armed on completion instead of a
  /// backing queue, which is inaudibly different for a look-ahead this short).
  func update() {
    guard let track, currentGroup != nil, !MIX_TrackPlaying(track) else { return }
    playNextTrack()
  }

  /// Stops the looping playlist, playing the current group's fade-out sting once first if it has
  /// one (`SndMusicEnd`'s `member(whichMusic & ".end")` lookup).
  func stop() {
    guard let track, let group = currentGroup else { return }
    currentGroup = nil
    if let end = group.end, let audio = audio(for: end) {
      _ = MIX_SetTrackAudio(track, audio)
      _ = MIX_PlayTrack(track, 0)
    } else {
      _ = MIX_StopTrack(track, 0)
    }
  }

  deinit {
    for audio in audioByFilename.values {
      MIX_DestroyAudio(audio)
    }
    if let track {
      MIX_DestroyTrack(track)
    }
  }
}
let musicPlayer = MusicPlayer(
  mixer: mixer, directory: repoRoot.appendingPathComponent("audio/music"))

// MARK: - Input

/// Last known mouse position in world space, kept up to date by every mouse event so the cursor
/// (updated once per frame in the main loop, not per-event) always reflects the current hover
/// target even on frames with no new mouse event.
var lastMouseWorldX: Int32 = 0
var lastMouseWorldY: Int32 = 0

@MainActor func handleMouseDown(x: Float, y: Float) {
  let world = gameEngine.canvasToWorld(
    canvasX: Double(x), canvasY: Double(y),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  lastMouseWorldX = Int32(world.x)
  lastMouseWorldY = Int32(world.y)
  gameEngine.mouseDown(lastMouseWorldX, lastMouseWorldY)
}
@MainActor func handleMouseMove(x: Float, y: Float) {
  let world = gameEngine.canvasToWorld(
    canvasX: Double(x), canvasY: Double(y),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  lastMouseWorldX = Int32(world.x)
  lastMouseWorldY = Int32(world.y)
  gameEngine.mouseMove(lastMouseWorldX, lastMouseWorldY)
}
@MainActor func handleMouseUp(x: Float, y: Float) {
  let world = gameEngine.canvasToWorld(
    canvasX: Double(x), canvasY: Double(y),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  lastMouseWorldX = Int32(world.x)
  lastMouseWorldY = Int32(world.y)
  gameEngine.mouseUp(lastMouseWorldX, lastMouseWorldY)
}

// MARK: - Cursor

/// Loads `images/cursors/cursor-*.png` into `SDL_Cursor`s (hotspot (8, 8), matching the JS
/// frontend's `url(...) 8 8` CSS cursor declarations) and swaps the OS cursor to match
/// `GameEngine.cursorHint` - the native-window equivalent of `render()`'s
/// `canvas.style.cursor = ...` chain in `src/game.js`.
final class CursorSet {
  private var cursors: [GameEngine.CursorHint: OpaquePointer] = [:]
  private var current: GameEngine.CursorHint = .none
  private let defaultCursor = SDL_GetDefaultCursor()

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
      guard let surface = IMG_Load(url.path) else { continue }
      defer { SDL_DestroySurface(surface) }
      guard let cursor = SDL_CreateColorCursor(surface, 8, 8) else { continue }
      cursors[hint] = cursor
    }
  }

  func apply(_ hint: GameEngine.CursorHint) {
    guard hint != current else { return }
    current = hint
    if let cursor = cursors[hint] {
      SDL_SetCursor(cursor)
    } else if let defaultCursor {
      SDL_SetCursor(defaultCursor)
    }
  }
}
let cursorSet = CursorSet(
  cursorsDirectory: repoRoot.appendingPathComponent("images/cursors"))

/// Draws its own cursor sprite via texture blit / `SDL_RenderGeometry`, rather than relying on
/// `SDL_SetCursor`/`SDL_ShowCursor` - some platforms (notably KMSDRM-backed Linux, as found on
/// ARM64 handhelds with no mouse hardware at all) have no hardware cursor plane and silently
/// render nothing for those calls, and `SDL_GetMouseState`/`SDL_WarpMouseInWindow` have no real
/// pointing device to route through either. Used only while `lastPointingInput == .gamepad` -
/// mouse/touch keep using the OS cursor (or no cursor) as before.
final class VirtualCursor {
  private let renderer: OpaquePointer
  private var textures: [GameEngine.CursorHint: UnsafeMutablePointer<SDL_Texture>] = [:]

  init(renderer: OpaquePointer, cursorsDirectory: URL) {
    self.renderer = renderer
    let files: [(GameEngine.CursorHint, String)] = [
      (.grabbing, "cursor-grabbing.png"),
      (.grabEither, "cursor-grab-either.png"),
      (.grabUpward, "cursor-grab-upward.png"),
      (.grabDownward, "cursor-grab-downward.png"),
      (.grab, "cursor-grab.png"),
    ]
    for (hint, filename) in files {
      let url = cursorsDirectory.appendingPathComponent(filename)
      guard let texture = IMG_LoadTexture(renderer, url.path) else { continue }
      textures[hint] = texture
    }
  }

  func draw(hint: GameEngine.CursorHint, x: Float, y: Float) {
    if let texture = textures[hint] {
      var width: Float = 0
      var height: Float = 0
      _ = SDL_GetTextureSize(texture, &width, &height)
      var dst = SDL_FRect(x: x - 8, y: y - 8, w: width, h: height)
      _ = SDL_RenderTexture(renderer, texture, nil, &dst)
      return
    }
    drawArrow(x: x, y: y)
  }

  /// Fallback arrow silhouette for `.none` (no grab image loaded for that hint) - a black outline
  /// triangle with a white fill, drawn as two overlapping `SDL_RenderGeometry` triangles.
  private func drawArrow(x: Float, y: Float) {
    func fillTriangle(_ points: [(Float, Float)], color: SDL_FColor) {
      var vertices = points.map {
        SDL_Vertex(
          position: SDL_FPoint(x: x + $0.0, y: y + $0.1), color: color,
          tex_coord: SDL_FPoint(x: 0, y: 0))
      }
      _ = SDL_RenderGeometry(renderer, nil, &vertices, Int32(vertices.count), nil, 0)
    }
    let black = SDL_FColor(r: 0, g: 0, b: 0, a: 1)
    let white = SDL_FColor(r: 1, g: 1, b: 1, a: 1)
    fillTriangle([(0, 0), (0, 16), (11, 12)], color: black)
    fillTriangle([(1, 3), (1, 13), (9, 11)], color: white)
  }
}
let virtualCursor = VirtualCursor(
  renderer: renderer, cursorsDirectory: repoRoot.appendingPathComponent("images/cursors"))

// MARK: - Rendering

/// Reused across frames to avoid per-frame allocation.
var renderFrame = RenderFrame()

/// Draws the gameplay world (entities/effects/mask) at the given screen-space camera offset.
/// Used by both `.playing` and `.title` (the title screen is itself a normal playable level, per
/// `src/game.js`'s `showTitleScreen` - see `Screens.swift`), and reused as the frozen backdrop
/// behind the win/lose dialogs. Returns the offset, for overlay drawing (e.g. the title screen's
/// welcome-panel text) that needs to line up with world-space coordinates.
@MainActor @discardableResult func renderWorld(editing: Bool) -> (offsetX: Float, offsetY: Float) {
  gameEngine.buildRenderFrame(into: &renderFrame, editing: editing)

  // World-space -> screen-space: with scale 1 the camera transform is a pure translation, so
  // compute it once rather than per command.
  let origin = gameEngine.worldToCanvas(
    worldX: 0, worldY: 0,
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  let offsetX = Float(origin.x)
  let offsetY = Float(origin.y)

  for command in renderFrame.commands {
    switch command.kind {
    case .solidRect:
      let rgba = UInt32(bitPattern: command.c)
      _ = SDL_SetRenderDrawColor(
        renderer,
        UInt8((rgba >> 24) & 0xFF), UInt8((rgba >> 16) & 0xFF), UInt8((rgba >> 8) & 0xFF),
        UInt8(rgba & 0xFF))
      var rect = SDL_FRect(
        x: Float(command.x) + offsetX, y: Float(command.y) + offsetY,
        w: Float(command.a), h: Float(command.b))
      _ = SDL_RenderFillRect(renderer, &rect)

    case .sprite:
      guard let texture = textureCache.texture(for: command.spriteID) else { continue }
      // Draw at the atlas frame's authoritative size (matching the JS renderer), not the
      // individual PNG's size, in case the two ever disagree.
      let w = Float(spriteWidthTable[Int(command.spriteID)])
      let h = Float(spriteHeightTable[Int(command.spriteID)])
      let clip = Float(command.c)
      var src: SDL_FRect? = nil
      var dstW = w
      if clip > 0 && clip < w {
        src = SDL_FRect(x: 0, y: 0, w: clip, h: h)
        dstW = clip
      }
      var dst = SDL_FRect(
        x: Float(command.x) + offsetX, y: Float(command.y) + offsetY, w: dstW, h: h)

      if command.a < 100 {
        _ = SDL_SetTextureAlphaMod(texture, UInt8(max(0, min(100, command.a)) * 255 / 100))
      }
      if command.b != 0 {
        // Milliradians -> degrees, rotating around the destination-rect center.
        let degrees = Double(command.b) / 1000 * 180 / Double.pi
        withUnsafeMutablePointer(to: &dst) { dstPtr in
          if var srcRect = src {
            _ = SDL_RenderTextureRotated(
              renderer, texture, &srcRect, dstPtr, degrees, nil, SDL_FLIP_NONE)
          } else {
            _ = SDL_RenderTextureRotated(renderer, texture, nil, dstPtr, degrees, nil, SDL_FLIP_NONE)
          }
        }
      } else if var srcRect = src {
        _ = SDL_RenderTexture(renderer, texture, &srcRect, &dst)
      } else {
        _ = SDL_RenderTexture(renderer, texture, nil, &dst)
      }
      if command.a < 100 {
        _ = SDL_SetTextureAlphaMod(texture, 255)
      }
    }
  }
  return (offsetX, offsetY)
}

@MainActor func render() {
  _ = SDL_SetRenderDrawColor(renderer, 40, 40, 45, 255)
  _ = SDL_RenderClear(renderer)

  switch currentScreen {
  case .title:
    let (offsetX, offsetY) = renderWorld(editing: false)
    drawTitleScreenOverlay(offsetX: offsetX, offsetY: offsetY)
  case .playing:
    renderWorld(editing: false)
    drawLevelToast()
  case .levelSelect(let game, let page):
    drawLevelSelectScreen(game: game, page: page)
  case .levelWinDialog, .levelLoseDialog:
    renderWorld(editing: false)
    drawDialogOverlay()
  }
  drawFocusRing()

  // Menu/d-pad navigation intentionally hides the cursor (the focus ring is the indicator
  // there) - only draw the virtual cursor on the screens where it's meant to be visible, and
  // only while `virtualCursorVisible` (false during d-pad menu-item focus navigation, even on
  // a world-owning screen like the title screen's Play/Credits buttons).
  if lastPointingInput == .gamepad, screenOwnsWorldInput(), virtualCursorVisible {
    let hint = gameEngine.cursorHint(worldX: lastMouseWorldX, worldY: lastMouseWorldY)
    virtualCursor.draw(hint: hint, x: lastMouseScreenX, y: lastMouseScreenY)
  }

  SDL_RenderPresent(renderer)
}

// MARK: - Game loop

showTitleScreen()

/// Matches `src/game.js`'s `targetFPS = 18` simulation tick rate (the game's actual logic rate,
/// independent of display refresh rate).
let tickIntervalNanoseconds: UInt64 = 1_000_000_000 / 18
var lastTickTime = SDL_GetTicksNS()

/// Whether the current screen ticks/renders the gameplay world with live drag input - both the
/// title screen (a normal playable level with draggable bricks, per `src/game.js`'s
/// `showTitleScreen`) and actual gameplay. Menu-only screens (level-select, win/lose dialogs)
/// don't tick the engine or forward mouse events to `GameEngine.mouseDown`/etc.
@MainActor func screenOwnsWorldInput() -> Bool {
  currentScreen == .title || currentScreen == .playing
}

/// Backs out one screen: gameplay (or its win/lose dialog) -> level select at the current
/// level's page, level select -> title. The HTML5 build has no Escape binding (its "Select
/// Level" is a DOM button); this is the native equivalent, shared by the Escape key and the
/// gamepad's Start button.
@MainActor func escapePressed() {
  switch currentScreen {
  case .playing, .levelWinDialog, .levelLoseDialog:
    soundBoard.play(MenuSoundID.buttonClick)
    dismissLevelToast()
    if let entry = currentLevelEntry,
      let location = levelCatalog.location(ofLevelTitled: entry.title, game: currentGame)
    {
      showLevelSelectScreen(game: currentGame, page: location.page)
    } else {
      showLevelSelectScreen(game: currentGame, page: 0)
    }
  case .levelSelect:
    soundBoard.play(MenuSoundID.buttonClick)
    showTitleScreen()
  case .title:
    break
  }
}

let gamepadState = GamepadState()
var lastFrameTime = SDL_GetTicksNS()

var running = true
while running {
  var event = SDL_Event()
  while SDL_PollEvent(&event) {
    switch event.type {
    case SDL_EVENT_QUIT.rawValue:
      running = false
    case SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue:
      let downPoint = windowToRenderPoint(x: event.button.x, y: event.button.y)
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
    case SDL_EVENT_MOUSE_BUTTON_UP.rawValue:
      if screenOwnsWorldInput() {
        let upPoint = windowToRenderPoint(x: event.button.x, y: event.button.y)
        handleMouseUp(x: upPoint.x, y: upPoint.y)
      }
    case SDL_EVENT_KEY_DOWN.rawValue:
      switch event.key.key {
      case SDLK_ESCAPE:
        escapePressed()
      case SDLK_UP:
        directionPressed(dx: 0, dy: -1, menuDelta: -1)
      case SDLK_DOWN:
        directionPressed(dx: 0, dy: 1, menuDelta: 1)
      case SDLK_LEFT:
        directionPressed(dx: -1, dy: 0, menuDelta: -1)
      case SDLK_RIGHT:
        directionPressed(dx: 1, dy: 0, menuDelta: 1)
      case SDLK_RETURN, SDLK_SPACE:
        activatePressed()
      default:
        break
      }
    case SDL_EVENT_KEY_UP.rawValue:
      if event.key.key == SDLK_RETURN || event.key.key == SDLK_SPACE {
        activateReleased()
      }
    case SDL_EVENT_MOUSE_MOTION.rawValue:
      let motionPoint = windowToRenderPoint(x: event.motion.x, y: event.motion.y)
      lastMouseScreenX = motionPoint.x
      lastMouseScreenY = motionPoint.y
      // Touch-synthesized mouse events carry SDL_TOUCH_MOUSEID. Programmatic warps (gamepad
      // stick/d-pad-nudge, via SDL_WarpMouseInWindow) set suppressNextMouseMotionAsSynthetic
      // right before warping so this one motion event is consumed without re-triggering
      // anything - those call sites already handled input-kind/cursor-visibility themselves.
      // Any *other* motion is genuine mouse hardware movement and must unconditionally show
      // the cursor and hand hover back to the mouse - this can never be skipped based on
      // `lastPointingInput`, or the cursor can get stuck hidden after gamepad/d-pad use.
      if event.motion.which == touchMouseID {
        notePointingInput(.touch)
      } else if suppressNextMouseMotionAsSynthetic {
        suppressNextMouseMotionAsSynthetic = false
      } else {
        lastPointingInput = .mouse
        _ = SDL_ShowCursor()
        focusedButtonIndex = nil
      }
      if screenOwnsWorldInput() {
        handleMouseMove(x: motionPoint.x, y: motionPoint.y)
      }
    case SDL_EVENT_FINGER_DOWN.rawValue, SDL_EVENT_FINGER_MOTION.rawValue:
      notePointingInput(.touch)
    case SDL_EVENT_GAMEPAD_ADDED.rawValue:
      gamepadState.handleAdded(event.gdevice.which)
    case SDL_EVENT_GAMEPAD_REMOVED.rawValue:
      gamepadState.handleRemoved(event.gdevice.which)
    case SDL_EVENT_GAMEPAD_BUTTON_DOWN.rawValue:
      switch SDL_GamepadButton(Int32(event.gbutton.button)) {
      case SDL_GAMEPAD_BUTTON_SOUTH:  // A
        notePointingInput(.gamepad)
        activatePressed()
      case SDL_GAMEPAD_BUTTON_START:
        escapePressed()
      case SDL_GAMEPAD_BUTTON_DPAD_UP:
        directionPressed(dx: 0, dy: -1, menuDelta: -1)
      case SDL_GAMEPAD_BUTTON_DPAD_DOWN:
        directionPressed(dx: 0, dy: 1, menuDelta: 1)
      case SDL_GAMEPAD_BUTTON_DPAD_LEFT:
        directionPressed(dx: -1, dy: 0, menuDelta: -1)
      case SDL_GAMEPAD_BUTTON_DPAD_RIGHT:
        directionPressed(dx: 1, dy: 0, menuDelta: 1)
      default:
        break
      }
    case SDL_EVENT_GAMEPAD_BUTTON_UP.rawValue:
      if SDL_GamepadButton(Int32(event.gbutton.button)) == SDL_GAMEPAD_BUTTON_SOUTH {
        activateReleased()
      }
    case SDL_EVENT_WINDOW_RESIZED.rawValue:
      // `windowWidth`/`windowHeight` are the fixed logical canvas size set once at startup (see
      // above) and deliberately NOT updated here - `SDL_LOGICAL_PRESENTATION_INTEGER_SCALE`
      // needs a stable logical size to scale up by whole multiples as the window resizes
      // (letterboxing the remainder); if this tracked the window's live size instead, the
      // logical-to-output ratio would always be exactly 1 and "integer scaling" would be a
      // no-op. SDL recomputes the actual integer scale factor and letterbox rect from the new
      // window size automatically on the next present - no explicit action needed here.
      break
    default:
      break
    }
  }

  let now = SDL_GetTicksNS()
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
  SDL_Delay(1)
}
