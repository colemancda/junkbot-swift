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

  override func didMove(to view: SKView) {
    guard !didStart else { return }
    didStart = true
    configureGameEngineCallbacks()
    configureKeyboardInput()
    gameRenderer = SpriteKitRenderer(scene: self)
    windowWidth = Int32(size.width)
    windowHeight = Int32(size.height)
    lastTickTime = currentTicksNanoseconds()
    showTitleScreen()
  }

  /// With `.resizeFill`, the scene's own size always tracks the view's actual size exactly (no
  /// scaling/letterboxing) - this keeps `windowWidth`/`windowHeight` (read by every world/camera
  /// calculation the shared files perform) in sync whenever the window/screen size changes.
  override func didChangeSize(_ oldSize: CGSize) {
    super.didChangeSize(oldSize)
    windowWidth = Int32(size.width)
    windowHeight = Int32(size.height)
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
    musicPlayer.update()
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
