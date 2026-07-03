import CSDL3
import CSDL3Image
import CSDL3Mixer
import Foundation
import JunkbotCore

// MARK: - Repo-relative paths

/// Resolved from this file's own compile-time path (`Sources/JunkbotSDL3/main.swift`), the same
/// trick `Tests/JunkbotCoreTests/LevelTests.swift` uses to find `levels/` without a resource
/// bundle. Fine for this dev-only native target — it isn't meant to be relocated/shipped standalone.
let repoRoot = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()  // main.swift
  .deletingLastPathComponent()  // JunkbotSDL3
  .deletingLastPathComponent()  // Sources
let levelsDirectory = repoRoot.appendingPathComponent("levels")
let spritesDirectory = repoRoot.appendingPathComponent("images/sprites")
let spritesUndercoverDirectory = spritesDirectory.appendingPathComponent("Undercover Exclusive")
let backgroundsDirectory = repoRoot.appendingPathComponent("images/backgrounds")
let backgroundsUndercoverDirectory = backgroundsDirectory.appendingPathComponent("Undercover Exclusive")
let audioDirectory = repoRoot.appendingPathComponent("audio/sound-effects")

// MARK: - Level sequencing

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

/// Collapses runs of whitespace to a single space, for matching titles that differ only in
/// incidental whitespace (a couple of `levels/*.txt` files have a typo'd double space in their
/// `title=` line, e.g. "Running  the Gauntlet" vs. `_LEVEL_LISTING.txt`'s "Running the Gauntlet").
func normalizedTitle(_ title: String) -> String {
  title.trimmingCharacters(in: .whitespaces).split(separator: " ").joined(separator: " ")
}

/// `_LEVEL_LISTING.txt`'s order is the source of truth for level progression, but its titles don't
/// always match their on-disk filename 1:1 (e.g. "Caution: Fire" -> "Caution Fire.txt", punctuation
/// stripped inconsistently) - so rather than guessing a sanitizer, every top-level `levels/*.txt`
/// file gets parsed once at startup and matched back to the listing by its *parsed* `[info] title=`,
/// which is always exact (modulo incidental whitespace, see `normalizedTitle`).
func loadLevelSequence() -> [(title: String, url: URL)] {
  let fileManager = FileManager.default
  guard
    let entries = try? fileManager.contentsOfDirectory(
      at: levelsDirectory, includingPropertiesForKeys: nil)
  else { return [] }

  var urlByTitle: [String: URL] = [:]
  for url in entries where url.pathExtension == "txt" {
    guard let text = readLevelText(at: url) else { continue }
    urlByTitle[normalizedTitle(Level(text: text).title)] = url
  }

  guard
    let listingText = readLevelText(at: levelsDirectory.appendingPathComponent("_LEVEL_LISTING.txt"))
  else { return [] }

  return listingText.split(separator: "\n").compactMap { line in
    let title = normalizedTitle(String(line))
    guard !title.isEmpty else { return nil }
    guard let url = urlByTitle[title] else {
      // Pre-existing data mismatch in a few `levels/*.txt` files (their `[info] title=` doesn't
      // match their `_LEVEL_LISTING.txt` entry, e.g. "The Garage.txt" actually contains "The
      // Engine Room") - not something to guess a fix for here, so just skip and report it.
      FileHandle.standardError.write(Data("Skipping unmatched level listing entry: \(title)\n".utf8))
      return nil
    }
    return (title, url)
  }
}

let levelSequence = loadLevelSequence()
guard !levelSequence.isEmpty else {
  FileHandle.standardError.write(Data("No levels found under \(levelsDirectory.path)\n".utf8))
  exit(1)
}

let gameEngine = GameEngine()
var currentLevelIndex = 0
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

@MainActor func loadCurrentLevel() {
  let (title, url) = levelSequence[currentLevelIndex]
  guard let text = readLevelText(at: url) else {
    FileHandle.standardError.write(Data("Failed to read \(url.path)\n".utf8))
    exit(1)
  }
  gameEngine.loadLevel(fromText: text)
  print("Level \(currentLevelIndex + 1)/\(levelSequence.count): \(title)")
  musicPlayer.startRandomLevelMusic()

  if let bounds = gameEngine.levelBounds {
    cameraCenterX = Double(bounds.x) + Double(bounds.width) / 2
    cameraCenterY = Double(bounds.y) + Double(bounds.height) / 2
  } else if !gameEngine.entities.isEmpty {
    let minX = gameEngine.entities.map(\.x).min() ?? 0
    let maxX = gameEngine.entities.map { $0.x + $0.width }.max() ?? 0
    let minY = gameEngine.entities.map(\.y).min() ?? 0
    let maxY = gameEngine.entities.map { $0.y + $0.height }.max() ?? 0
    cameraCenterX = Double(minX + maxX) / 2
    cameraCenterY = Double(minY + maxY) / 2
  }
}

@MainActor func advanceToNextLevel() {
  currentLevelIndex = (currentLevelIndex + 1) % levelSequence.count
  loadCurrentLevel()
}

// MARK: - SDL setup

guard SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) else {
  FileHandle.standardError.write(Data("SDL_Init failed: \(String(cString: SDL_GetError()))\n".utf8))
  exit(1)
}
defer { SDL_Quit() }

// Load the first level before creating the window, so the window's default size can match its
// actual bounds (no letterboxing on startup) instead of an arbitrary fixed guess. The window
// stays resizable afterward for levels of other sizes (see SDL_EVENT_WINDOW_RESIZED below).
gameEngine.loadLevel(fromText: readLevelText(at: levelSequence[currentLevelIndex].url) ?? "")
var windowWidth: Int32 = gameEngine.levelBounds.map { $0.width } ?? 900
var windowHeight: Int32 = gameEngine.levelBounds.map { $0.height } ?? 675
// SDL_WINDOW_RESIZABLE's macro (SDL_UINT64_C(...)) doesn't import into Swift - its raw value
// (SDL_video.h) is 0x0000000000000020.
let windowResizableFlag: SDL_WindowFlags = 0x0000_0000_0000_0020
guard let window = SDL_CreateWindow("Junkbot", windowWidth, windowHeight, windowResizableFlag)
else {
  FileHandle.standardError.write(Data("SDL_CreateWindow failed: \(String(cString: SDL_GetError()))\n".utf8))
  exit(1)
}
defer { SDL_DestroyWindow(window) }

guard let renderer = SDL_CreateRenderer(window, nil) else {
  FileHandle.standardError.write(Data("SDL_CreateRenderer failed: \(String(cString: SDL_GetError()))\n".utf8))
  exit(1)
}
defer { SDL_DestroyRenderer(renderer) }

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

// MARK: - Rendering

/// Reused across frames to avoid per-frame allocation.
var renderFrame = RenderFrame()

@MainActor func render() {
  _ = SDL_SetRenderDrawColor(renderer, 40, 40, 45, 255)
  _ = SDL_RenderClear(renderer)

  gameEngine.buildRenderFrame(into: &renderFrame, editing: false)

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

  SDL_RenderPresent(renderer)
}

// MARK: - Game loop

loadCurrentLevel()

/// Matches `src/game.js`'s `targetFPS = 18` simulation tick rate (the game's actual logic rate,
/// independent of display refresh rate).
let tickIntervalNanoseconds: UInt64 = 1_000_000_000 / 18
var lastTickTime = SDL_GetTicksNS()
/// Brief pause after a win before loading the next level, so the win is visible for a moment
/// rather than instantly cutting to the next level.
let winPauseNanoseconds: UInt64 = 1_500_000_000
var winPauseUntil: UInt64? = nil

var running = true
while running {
  var event = SDL_Event()
  while SDL_PollEvent(&event) {
    switch event.type {
    case SDL_EVENT_QUIT.rawValue:
      running = false
    case SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue:
      handleMouseDown(x: event.button.x, y: event.button.y)
    case SDL_EVENT_MOUSE_BUTTON_UP.rawValue:
      handleMouseUp(x: event.button.x, y: event.button.y)
    case SDL_EVENT_MOUSE_MOTION.rawValue:
      handleMouseMove(x: event.motion.x, y: event.motion.y)
    case SDL_EVENT_WINDOW_RESIZED.rawValue:
      // Mirrors the JS frontend's canvas resizing to fill the browser window (src/game.js's
      // `innerWidth`/`innerHeight` resize check) - the camera/viewport math above already
      // reads `windowWidth`/`windowHeight` as plain vars, so updating them here is enough.
      windowWidth = event.window.data1
      windowHeight = event.window.data2
    default:
      break
    }
  }

  let now = SDL_GetTicksNS()
  if let pauseUntil = winPauseUntil {
    if now >= pauseUntil {
      winPauseUntil = nil
      advanceToNextLevel()
    }
  } else {
    while now - lastTickTime >= tickIntervalNanoseconds {
      lastTickTime += tickIntervalNanoseconds
      gameEngine.tick()
      if gameEngine.winLose() == 1 {
        winPauseUntil = now + winPauseNanoseconds
        // Mirrors parent_game manager.ls's endLevel calling SndMusicEnd() before the next
        // level's SndMusicStart(); the winPauseNanoseconds gap before advanceToNextLevel()
        // gives the fade-out sting (if any) room to actually be heard.
        musicPlayer.stop()
        break
      }
    }
  }

  updateCamera()
  cursorSet.apply(gameEngine.cursorHint(worldX: lastMouseWorldX, worldY: lastMouseWorldY))
  musicPlayer.update()
  render()
  SDL_Delay(1)
}
