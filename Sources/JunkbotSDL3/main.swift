import CSDL3
import CSDL3Image
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

guard SDL_Init(SDL_INIT_VIDEO) else {
  FileHandle.standardError.write(Data("SDL_Init failed: \(String(cString: SDL_GetError()))\n".utf8))
  exit(1)
}
defer { SDL_Quit() }

let windowWidth: Int32 = 900
let windowHeight: Int32 = 675
guard let window = SDL_CreateWindow("Junkbot", windowWidth, windowHeight, 0) else {
  FileHandle.standardError.write(Data("SDL_CreateWindow failed: \(String(cString: SDL_GetError()))\n".utf8))
  exit(1)
}
defer { SDL_DestroyWindow(window) }

guard let renderer = SDL_CreateRenderer(window, nil) else {
  FileHandle.standardError.write(Data("SDL_CreateRenderer failed: \(String(cString: SDL_GetError()))\n".utf8))
  exit(1)
}
defer { SDL_DestroyRenderer(renderer) }

// MARK: - Sprite loading (mirrors src/game.js's sprite atlas, but loads each PNG individually
// rather than reproducing the atlas/JSON lookup - see SpriteMapping.swift)

final class TextureCache {
  private var textures: [String: UnsafeMutablePointer<SDL_Texture>] = [:]
  private var attemptedAndMissing: Set<String> = []
  let renderer: OpaquePointer

  init(renderer: OpaquePointer) {
    self.renderer = renderer
  }

  /// Loads (and caches) the texture named `name` (no extension), trying the base sprites
  /// directory first, then the Undercover-exclusive one (where crates/teleports/lasers/non-fixed
  /// shields live). Returns `nil` if no such file exists in either location.
  func texture(named name: String) -> UnsafeMutablePointer<SDL_Texture>? {
    if let cached = textures[name] { return cached }
    guard !attemptedAndMissing.contains(name) else { return nil }

    let candidates = [
      spritesDirectory.appendingPathComponent("\(name).png"),
      spritesUndercoverDirectory.appendingPathComponent("\(name).png"),
    ]
    for url in candidates {
      guard FileManager.default.fileExists(atPath: url.path) else { continue }
      guard let surface = IMG_Load(url.path) else { continue }
      defer { SDL_DestroySurface(surface) }
      guard let texture = SDL_CreateTextureFromSurface(renderer, surface) else { continue }
      textures[name] = texture
      return texture
    }
    attemptedAndMissing.insert(name)
    return nil
  }

  deinit {
    for texture in textures.values {
      SDL_DestroyTexture(texture)
    }
  }
}
let textureCache = TextureCache(renderer: renderer)

/// A flat fallback color for entity types/states with no resolved sprite (shouldn't normally hit
/// this - `spriteName(for:)` covers every `EntityType` - but a source PNG could still be missing
/// on disk).
func fallbackColor(for e: Entity) -> (r: UInt8, g: UInt8, b: UInt8) {
  switch e.type {
  case .brick: return e.fixed ? (120, 120, 120) : (80, 140, 220)
  case .junkbot: return (240, 150, 40)
  case .bin: return (60, 90, 200)
  default: return (200, 60, 60)
  }
}

// MARK: - Input

@MainActor func handleMouseDown(x: Float, y: Float) {
  let world = gameEngine.canvasToWorld(
    canvasX: Double(x), canvasY: Double(y),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  gameEngine.mouseDown(Int32(world.x), Int32(world.y))
}
@MainActor func handleMouseMove(x: Float, y: Float) {
  let world = gameEngine.canvasToWorld(
    canvasX: Double(x), canvasY: Double(y),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  gameEngine.mouseMove(Int32(world.x), Int32(world.y))
}
@MainActor func handleMouseUp(x: Float, y: Float) {
  let world = gameEngine.canvasToWorld(
    canvasX: Double(x), canvasY: Double(y),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  gameEngine.mouseUp(Int32(world.x), Int32(world.y))
}

// MARK: - Rendering

@MainActor func render() {
  _ = SDL_SetRenderDrawColor(renderer, 40, 40, 45, 255)
  _ = SDL_RenderClear(renderer)

  let boxes = gameEngine.entities.map {
    RenderBox(x: Double($0.x), y: Double($0.y), width: Double($0.width), height: Double($0.height))
  }
  for index in sortOrderForRendering(boxes) {
    let entity = gameEngine.entities[index]
    let screen = gameEngine.worldToCanvas(
      worldX: Double(entity.x), worldY: Double(entity.y),
      centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
      canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
    let offsetX = Float(screen.x) - Float(entity.x)
    let offsetY = Float(screen.y) - Float(entity.y)

    if entity.type == .junkbot {
      let frame = junkbotFrame(for: entity)
      if let texture = textureCache.texture(named: frame.spriteName) {
        var texW: Float = 0
        var texH: Float = 0
        _ = SDL_GetTextureSize(texture, &texW, &texH)
        // Matches drawJunkbot's `junkbot.x - offset.x, junkbot.y + junkbot.height - 1 - height - offset.y`.
        var dst = SDL_FRect(
          x: Float(entity.x) - Float(frame.offsetX) + offsetX,
          y: Float(entity.y) + Float(entity.height) - 1 - texH - Float(frame.offsetY) + offsetY,
          w: texW, h: texH)
        _ = SDL_RenderTexture(renderer, texture, nil, &dst)
        continue
      }
    }

    if let name = spriteName(for: entity), let texture = textureCache.texture(named: name) {
      var texW: Float = 0
      var texH: Float = 0
      _ = SDL_GetTextureSize(texture, &texW, &texH)
      let position = spriteDrawPosition(for: entity, textureWidth: texW, textureHeight: texH)
      var dst = SDL_FRect(
        x: position.x + offsetX, y: position.y + offsetY, w: texW, h: texH)
      _ = SDL_RenderTexture(renderer, texture, nil, &dst)
    } else {
      let color = fallbackColor(for: entity)
      _ = SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, 255)
      var rect = SDL_FRect(
        x: Float(screen.x), y: Float(screen.y), w: Float(entity.width), h: Float(entity.height))
      _ = SDL_RenderFillRect(renderer, &rect)
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
        break
      }
    }
  }

  updateCamera()
  render()
  SDL_Delay(1)
}
