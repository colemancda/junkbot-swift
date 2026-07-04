import SDL2Swift
import Foundation
import JunkbotCore

// Gamepad + keyboard navigation and input-kind-aware cursor visibility (Phase 7). Design note:
// the gamepad's left stick moves the *real* OS cursor via `window.warpMouse(to:)`, which
// generates ordinary mouse-motion events - so every existing input path (world drags, menu
// hover, the level-select rollover bar, grab cursors) works unchanged, and the A button just
// synthesizes the same code paths a mouse click takes.

@GameActor var lastPointingInput: PointingInputKind = .mouse
@GameActor var virtualCursorVisible = false
@GameActor var suppressNextMouseMotionAsSynthetic = false

@GameActor func notePointingInput(_ kind: PointingInputKind) {
  guard kind != lastPointingInput else { return }
  lastPointingInput = kind
  switch kind {
  case .mouse:
    SDL.isCursorVisible = true
  case .gamepad, .touch:
    SDL.isCursorVisible = false
  }
}

// MARK: - Gamepad

@GameActor final class GamepadState {
  private var gamepad: SDLGamepad?
  private let deadzone: Float = 8000 / 32767
  private let cursorSpeed: Float = 600

  func handleAdded(_ joystickID: JoystickID) {
    gamepad = try? SDLGamepad(joystickID: joystickID)
  }

  func handleRemoved(_ joystickID: JoystickID) {
    guard let gamepad, gamepad.id == joystickID else { return }
    self.gamepad = nil
  }

  func pollSticks(deltaSeconds: Float) {
    guard let gamepad, screenOwnsWorldInput() else { return }
    let rawX = Float(gamepad.axis(.leftX)) / 32767
    let rawY = Float(gamepad.axis(.leftY)) / 32767
    let x = abs(rawX) > deadzone ? rawX : 0
    let y = abs(rawY) > deadzone ? rawY : 0
    guard x != 0 || y != 0 else { return }
    notePointingInput(.gamepad)
    virtualCursorVisible = true

    if lastMouseScreenX < 0 { lastMouseScreenX = Float(windowWidth) / 2 }
    if lastMouseScreenY < 0 { lastMouseScreenY = Float(windowHeight) / 2 }

    let newX = max(0, min(Float(windowWidth) - 1, lastMouseScreenX + x * cursorSpeed * deltaSeconds))
    let newY = max(0, min(Float(windowHeight) - 1, lastMouseScreenY + y * cursorSpeed * deltaSeconds))
    lastMouseScreenX = newX
    lastMouseScreenY = newY
    warpCursor(x: newX, y: newY)
    handleMouseMove(x: newX, y: newY)
  }
}

// MARK: - Menu focus (keyboard / d-pad navigation)
//
// The portable logic (`focusedButtonIndex`, `moveFocus`, `directionPressed`, `nudgeDrag`,
// `activatePressed`, `activateReleased`) lives in the shared, symlinked `MenuFocus.swift`
// (identical across `ports/SDL3`/`ports/SDL2`/`ports/Darwin`). It calls back into these two
// SDL-specific neutral wrappers instead of raw calls directly, the same pattern `main.swift`'s
// `currentTicksNanoseconds()`/`openExternalURL(_:)` already use.

func hideOSCursor() {
  SDL.isCursorVisible = false
}

@GameActor func warpCursor(x: Float, y: Float) {
  suppressNextMouseMotionAsSynthetic = true
  let windowPoint = renderToWindowPoint(x: x, y: y)
  window.warpMouse(to: windowPoint)
}
