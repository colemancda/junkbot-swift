import Foundation
import JunkbotCore

// Backend-agnostic per-frame rendering: everything here only touches `GameRenderer` (never a
// raw SDL/SpriteKit call directly), so it's identical across every port (`ports/SDL3`,
// `ports/SDL2`, `ports/Darwin`'s SpriteKit backend). Each platform's own entry point just needs
// to provide the globals this depends on: `gameRenderer`, `windowWidth`/`windowHeight`,
// `cameraCenterX/Y`, `cameraScale`, `gameEngine`, `repoRoot`, `soundBoard`.

// MARK: - Sprite loading

/// Texture cache keyed by the generated sprite ID (`Generated/SpriteTable.swift`). Individual
/// per-frame PNGs (rather than the JS frontend's packed spritesheets) are loaded by the ID's
/// atlas name from `images/sprites` / `images/backgrounds` (each with an "Undercover Exclusive"
/// subdirectory) - the individual files share the atlas's exact frame names.
final class TextureCache {
  private var textures: [Int32: OpaquePointer] = [:]
  private var attemptedAndMissing: Set<Int32> = []
  let renderer: GameRenderer

  init(renderer: GameRenderer) {
    self.renderer = renderer
  }

  func texture(for spriteID: Int32) -> OpaquePointer? {
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
      guard let texture = renderer.loadTexture(atPath: url.path) else { continue }
      // Every backend defaults new textures to linear filtering, which blurs pixel art
      // whenever a sprite isn't drawn at exact 1:1 scale (i.e. almost always, given camera
      // zoom/offset). The JS canvas path sets `ctx.imageSmoothingEnabled = false` for the same
      // reason.
      renderer.setTextureNearestScaling(texture)
      textures[spriteID] = texture
      return texture
    }
    attemptedAndMissing.insert(spriteID)
    return nil
  }

  deinit {
    for texture in textures.values {
      renderer.destroyTexture(texture)
    }
  }
}
nonisolated(unsafe) let textureCache = TextureCache(renderer: gameRenderer)

/// Bitmap-font text rendering for menu UI (title/level-select/win-lose dialogs) - see
/// `TextRenderer.swift`/`Sources/JunkbotCore/Font.swift`.
nonisolated(unsafe) let textRenderer = TextRenderer(renderer: gameRenderer, fontDirectory: repoRoot.appendingPathComponent("font"))

// MARK: - Virtual cursor

/// Draws its own cursor sprite via texture blit / a filled triangle fallback, rather than
/// relying on the OS's own hardware cursor - some platforms (notably KMSDRM-backed Linux
/// handhelds with no mouse hardware at all) have no hardware cursor plane and silently render
/// nothing for those calls. Used only while `lastPointingInput == .gamepad` - mouse/touch keep
/// using the OS cursor (or no cursor) as before.
final class VirtualCursor {
  private let renderer: GameRenderer
  private var textures: [GameEngine.CursorHint: OpaquePointer] = [:]

  init(renderer: GameRenderer, cursorsDirectory: URL) {
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
      guard let texture = renderer.loadTexture(atPath: url.path) else { continue }
      textures[hint] = texture
    }
  }

  func draw(hint: GameEngine.CursorHint, x: Float, y: Float) {
    if let texture = textures[hint] {
      let (width, height) = renderer.textureSize(texture)
      renderer.drawTexture(
        texture, src: nil, dstX: x - 8, dstY: y - 8, dstW: width, dstH: height,
        rotationDegrees: nil)
      return
    }
    drawArrow(x: x, y: y)
  }

  /// Fallback arrow silhouette for `.none` (no grab image loaded for that hint) - a black outline
  /// triangle with a white fill.
  private func drawArrow(x: Float, y: Float) {
    func fillTriangle(_ points: [(Float, Float)], r: UInt8, g: UInt8, b: UInt8) {
      renderer.fillTriangle(points.map { (x: x + $0.0, y: y + $0.1) }, r: r, g: g, b: b, a: 255)
    }
    fillTriangle([(0, 0), (0, 16), (11, 12)], r: 0, g: 0, b: 0)
    fillTriangle([(1, 3), (1, 13), (9, 11)], r: 255, g: 255, b: 255)
  }
}
nonisolated(unsafe) let virtualCursor = VirtualCursor(
  renderer: gameRenderer, cursorsDirectory: repoRoot.appendingPathComponent("images/cursors"))

// MARK: - Rendering

/// Reused across frames to avoid per-frame allocation.
nonisolated(unsafe) var renderFrame = RenderFrame()

/// Whether the current screen ticks/renders the gameplay world with live drag input - both the
/// title screen (a normal playable level with draggable bricks, per `src/game.js`'s
/// `showTitleScreen`) and actual gameplay. Menu-only screens (level-select, win/lose dialogs)
/// don't tick the engine or forward mouse events to `GameEngine.mouseDown`/etc.
func screenOwnsWorldInput() -> Bool {
  currentScreen == .title || currentScreen == .playing
}

/// Backs out one screen: gameplay (or its win/lose dialog) -> level select at the current
/// level's page, level select -> title. The HTML5 build has no Escape binding (its "Select
/// Level" is a DOM button); this is the native equivalent, shared by the Escape key and the
/// gamepad's Start button.
func escapePressed() {
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

/// Draws the gameplay world (entities/effects/mask) at the given screen-space camera offset.
/// Used by both `.playing` and `.title` (the title screen is itself a normal playable level, per
/// `src/game.js`'s `showTitleScreen` - see `Screens.swift`), and reused as the frozen backdrop
/// behind the win/lose dialogs. Returns the offset, for overlay drawing (e.g. the title screen's
/// welcome-panel text) that needs to line up with world-space coordinates.
@discardableResult func renderWorld(editing: Bool) -> (offsetX: Float, offsetY: Float) {
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
      gameRenderer.fillRect(
        x: Float(command.x) + offsetX, y: Float(command.y) + offsetY,
        w: Float(command.a), h: Float(command.b),
        r: UInt8((rgba >> 24) & 0xFF), g: UInt8((rgba >> 16) & 0xFF), b: UInt8((rgba >> 8) & 0xFF),
        a: UInt8(rgba & 0xFF))

    case .sprite:
      guard let texture = textureCache.texture(for: command.spriteID) else { continue }
      // Draw at the atlas frame's authoritative size (matching the JS renderer), not the
      // individual PNG's size, in case the two ever disagree.
      let w = Float(spriteWidthTable[Int(command.spriteID)])
      let h = Float(spriteHeightTable[Int(command.spriteID)])
      let clip = Float(command.c)
      var src: (x: Float, y: Float, w: Float, h: Float)?
      var dstW = w
      if clip > 0 && clip < w {
        src = (x: 0, y: 0, w: clip, h: h)
        dstW = clip
      }

      if command.a < 100 {
        gameRenderer.setTextureAlpha(texture, percent: command.a)
      }
      let rotationDegrees: Double? = command.b != 0 ? Double(command.b) / 1000 * 180 / Double.pi : nil
      gameRenderer.drawTexture(
        texture, src: src, dstX: Float(command.x) + offsetX, dstY: Float(command.y) + offsetY,
        dstW: dstW, dstH: h, rotationDegrees: rotationDegrees)
      if command.a < 100 {
        gameRenderer.setTextureAlpha(texture, percent: nil)
      }
    }
  }
  return (offsetX, offsetY)
}

func render() {
  gameRenderer.clear(r: 40, g: 40, b: 45, a: 255)

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

  gameRenderer.present()
}
