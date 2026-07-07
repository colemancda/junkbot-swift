import SpriteKit
import JunkbotCore

/// The one `SKScene` this app ever presents - drives the same `gameEngine.tick()` /
/// `render()` (`GameRender.swift`, shared with `ports/SDL3`/`ports/SDL2`) loop those SDL ports
/// run from their own blocking event loops, just from SpriteKit's `update(_:)` callback instead.
/// SpriteKit is used purely for rendering here (via `SpriteKitRenderer`/`gameRenderer`) - there
/// is deliberately no `SKPhysicsBody`/`physicsWorld` usage anywhere; `GameEngine` remains the
/// sole simulation authority, exactly as on every other port.
final class JunkbotScene: SKScene {
  /// Matches `src/game.js`'s `targetFPS = 18` simulation tick rate - the game's actual logic
  /// rate, independent of the display's frame rate.
  private let tickIntervalNanoseconds: UInt64 = 1_000_000_000 / 18
  private var lastTickTime: UInt64 = 0
  private var didStart = false
  /// For `gamepadState.pollSticks(deltaSeconds:)` - SpriteKit's `update(_:)` only gives an
  /// absolute timestamp, not a per-frame delta the way SDL's own frame timer does.
  private var lastFrameTime: TimeInterval?
  /// Tracks the previous frame's 3D-active state, so entering/leaving 3D mode (toggled via
  /// `Settings.render3DEnabled`, or just entering/leaving `.playing`) only resets/reframes
  /// `scene3DManager` on the actual transition, not every frame.
  private var scene3DWasActive = false

  override func didMove(to view: SKView) {
    guard !didStart else { return }
    didStart = true
    configureGameEngineCallbacks()
    configureKeyboardInput()
    gameRenderer = SpriteKitRenderer(scene: self)
    // `windowWidth`/`windowHeight` are already set by whichever platform entry point
    // (`AppDelegate_macOS.swift`/`GameViewController.swift`) constructed this scene, matching its
    // fixed logical size exactly - not reassigned here, since `.aspectFit` never changes the
    // scene's own `size` as the window/screen resizes (unlike `.resizeFill`, which would have).
    lastTickTime = currentTicksNanoseconds()
    showTitleScreen()
  }

  override func update(_ currentTime: TimeInterval) {
    guard didStart else { return }
    let deltaSeconds = lastFrameTime.map { Float(currentTime - $0) } ?? 0
    lastFrameTime = currentTime
    gamepadState.pollSticks(deltaSeconds: deltaSeconds)

    let now = currentTicksNanoseconds()
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
    #if os(macOS)
    if lastPointingInput == .mouse, screenOwnsWorldInput() {
      cursorSet.apply(gameEngine.cursorHint(worldX: lastMouseWorldX, worldY: lastMouseWorldY))
    }
    #endif
    musicPlayer.update()

    // Play-mode-only 3D (see `Settings.render3DEnabled`'s doc comment): on the transition into or
    // out of it, reset `scene3DManager`'s entity-node table (a fresh level's entity IDs mean
    // nothing to whatever nodes are already tracked) and reframe its camera; every frame while
    // active, sync it from the latest tick's entities and suppress the 2D world-sprite draw so
    // the 3D scene shows through the now-transparent `SKView` instead of being drawn over.
    let scene3DShouldBeActive = Settings.render3DEnabled && currentScreen == .playing
    if scene3DShouldBeActive != scene3DWasActive {
      scene3DWasActive = scene3DShouldBeActive
      scnView?.isHidden = !scene3DShouldBeActive
      if scene3DShouldBeActive {
        scene3DManager.reset()
        scene3DManager.loadBackdrop(spriteID: gameEngine.backdropSpriteID)
      }
    }
    suppressWorldSpriteDrawing = scene3DShouldBeActive
    if scene3DShouldBeActive {
      scene3DManager.sync(entities: gameEngine.entities)
      scene3DManager.syncCamera()
    }

    render()
  }

  // MARK: - Pointer input (mouse on macOS, touch on iOS/tvOS)
  //
  // Menu buttons sit visually on top of the world (the title screen overlays Play/Credits on
  // top of its draggable-bricks scene), so they're hit-tested first regardless of screen - only
  // fall through to world drag input if nothing was clicked. Mirrors the exact same ordering in
  // `ports/SDL3/Sources/JunkbotSDL3/main.swift`'s `SDL_EVENT_MOUSE_BUTTON_DOWN` handling.

  private func pointDown(at point: CGPoint) {
    let renderPoint = gameRenderer.windowToRender(x: Float(point.x), y: Float(point.y))
    lastMouseScreenX = renderPoint.x
    lastMouseScreenY = renderPoint.y
    if levelToastUntil != nil {
      dismissLevelToast()
      return
    }
    if !handleClick(menuButtons, at: renderPoint.x, y: renderPoint.y), screenOwnsWorldInput() {
      handleMouseDown(x: renderPoint.x, y: renderPoint.y)
    }
  }

  private func pointMoved(to point: CGPoint) {
    let renderPoint = gameRenderer.windowToRender(x: Float(point.x), y: Float(point.y))
    lastMouseScreenX = renderPoint.x
    lastMouseScreenY = renderPoint.y
    if screenOwnsWorldInput() {
      handleMouseMove(x: renderPoint.x, y: renderPoint.y)
    }
  }

  private func pointUp(at point: CGPoint) {
    let renderPoint = gameRenderer.windowToRender(x: Float(point.x), y: Float(point.y))
    if screenOwnsWorldInput() {
      handleMouseUp(x: renderPoint.x, y: renderPoint.y)
    }
  }

  #if canImport(UIKit)
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    notePointingInput(.touch)
    pointDown(at: touch.location(in: self))
  }
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    pointMoved(to: touch.location(in: self))
  }
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    pointUp(at: touch.location(in: self))
  }
  #else
  override func mouseDown(with event: NSEvent) {
    notePointingInput(.mouse)
    focusedButtonIndex = nil
    pointDown(at: event.location(in: self))
  }
  override func mouseDragged(with event: NSEvent) {
    notePointingInput(.mouse)
    pointMoved(to: event.location(in: self))
  }
  override func mouseUp(with event: NSEvent) {
    pointUp(at: event.location(in: self))
  }
  override func mouseMoved(with event: NSEvent) {
    notePointingInput(.mouse)
    focusedButtonIndex = nil
    pointMoved(to: event.location(in: self))
  }
  #endif
}
