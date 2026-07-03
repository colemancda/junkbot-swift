import CSDL3
import Foundation
import JunkbotCore

// Gamepad + keyboard navigation and input-kind-aware cursor visibility (Phase 7). Design note:
// the gamepad's left stick moves the *real* OS cursor via SDL_WarpMouseInWindow, which
// generates ordinary SDL_EVENT_MOUSE_MOTION events - so every existing input path (world
// drags, menu hover, the level-select rollover bar, grab cursors) works unchanged, and the A
// button just synthesizes the same code paths a mouse click takes.

// MARK: - Input-kind tracking (cursor visibility)

/// Which kind of pointing input the user touched last. Touch hides the OS cursor; mouse or
/// gamepad shows it.
enum PointingInputKind {
  case mouse
  case gamepad
  case touch
}

@MainActor var lastPointingInput: PointingInputKind = .mouse

/// `SDL_TOUCH_MOUSEID`'s value - the macro is a C cast expression (`(SDL_MouseID)-1`) that
/// doesn't import into Swift. Mouse events synthesized from touch carry this `which` id;
/// filtering on it keeps them from flipping the input kind back to `.mouse`.
let touchMouseID: UInt32 = .max

@MainActor func notePointingInput(_ kind: PointingInputKind) {
  guard kind != lastPointingInput else { return }
  lastPointingInput = kind
  if kind == .touch {
    _ = SDL_HideCursor()
  } else {
    _ = SDL_ShowCursor()
  }
}

// MARK: - Gamepad

/// One active controller (last plugged-in wins), with per-frame left-stick polling that moves
/// the cursor at constant velocity. Polling (rather than reacting to axis-motion events) gives
/// smooth movement independent of the event delivery rate.
@MainActor final class GamepadState {
  private var gamepad: OpaquePointer?
  /// Fraction of full deflection below which the stick reads as centered (~24%).
  private let deadzone: Float = 8000 / 32767
  /// Cursor speed at full stick deflection, in window pixels per second.
  private let cursorSpeed: Float = 600

  func handleAdded(_ joystickID: SDL_JoystickID) {
    if let existing = gamepad {
      SDL_CloseGamepad(existing)
    }
    gamepad = SDL_OpenGamepad(joystickID)
  }

  func handleRemoved(_ joystickID: SDL_JoystickID) {
    guard let gamepad, SDL_GetGamepadID(gamepad) == joystickID else { return }
    SDL_CloseGamepad(gamepad)
    self.gamepad = nil
  }

  /// Reads the left stick and warps the cursor accordingly. Call once per frame.
  func pollSticks(deltaSeconds: Float) {
    guard let gamepad else { return }
    let rawX = Float(SDL_GetGamepadAxis(gamepad, SDL_GAMEPAD_AXIS_LEFTX)) / 32767
    let rawY = Float(SDL_GetGamepadAxis(gamepad, SDL_GAMEPAD_AXIS_LEFTY)) / 32767
    let x = abs(rawX) > deadzone ? rawX : 0
    let y = abs(rawY) > deadzone ? rawY : 0
    guard x != 0 || y != 0 else { return }
    notePointingInput(.gamepad)

    var mouseX: Float = 0
    var mouseY: Float = 0
    _ = SDL_GetMouseState(&mouseX, &mouseY)
    let newX = max(0, min(Float(windowWidth) - 1, mouseX + x * cursorSpeed * deltaSeconds))
    let newY = max(0, min(Float(windowHeight) - 1, mouseY + y * cursorSpeed * deltaSeconds))
    // Generates a normal SDL_EVENT_MOUSE_MOTION, driving all existing hover/drag paths.
    SDL_WarpMouseInWindow(window, newX, newY)
  }
}

// MARK: - Menu focus (keyboard / d-pad navigation)

/// Index into `menuButtons` of the keyboard/d-pad-focused button, or nil when the mouse owns
/// hover. Cleared on screen changes (menuButtons rebuilds) and on real mouse motion.
@MainActor var focusedButtonIndex: Int?

@MainActor func moveFocus(_ delta: Int) {
  guard !menuButtons.isEmpty else { return }
  if let current = focusedButtonIndex {
    focusedButtonIndex = (current + delta + menuButtons.count) % menuButtons.count
  } else {
    // First navigation press with no focus: start at the top rather than jumping by delta.
    focusedButtonIndex = 0
  }
}

/// Dispatches an arrow-key/d-pad press: while a brick is grabbed, it nudges the drag exactly
/// one stud/brick-height in that direction instead of moving menu focus - useful for precise
/// placement without depending on stick/cursor accuracy.
@MainActor func directionPressed(dx: Int32, dy: Int32, menuDelta: Int) {
  if gameEngine.isDragging {
    nudgeDrag(dx: dx, dy: dy)
  } else {
    moveFocus(menuDelta)
  }
}

/// Moves the dragged group by exactly one grid cell (`CELL_W`/`CELL_H`) in the given direction,
/// by advancing the tracked mouse position and feeding it through the same
/// `GameEngine.mouseMove` the real mouse/gamepad cursor already uses - so snapping, direction
/// resolution, etc. all behave identically. Also warps the real cursor to match, so a
/// subsequent click/A-release lines up with what's on screen.
@MainActor func nudgeDrag(dx: Int32, dy: Int32) {
  lastMouseWorldX += dx * CELL_W
  lastMouseWorldY += dy * CELL_H
  gameEngine.mouseMove(lastMouseWorldX, lastMouseWorldY)

  let canvas = gameEngine.worldToCanvas(
    worldX: Double(lastMouseWorldX), worldY: Double(lastMouseWorldY),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  lastMouseScreenX = Float(canvas.x)
  lastMouseScreenY = Float(canvas.y)
  SDL_WarpMouseInWindow(window, lastMouseScreenX, lastMouseScreenY)
}

/// Activates the focused menu button if any; otherwise (gameplay/title with a controller)
/// synthesizes a mouse press/release at the cursor so A grabs/releases bricks with the exact
/// mouse semantics (drag direction resolution, canRelease-gated drops, toast dismissal).
@MainActor func activatePressed() {
  if levelToastUntil != nil {
    dismissLevelToast()
    return
  }
  if let index = focusedButtonIndex, index < menuButtons.count {
    menuButtons[index].action()
    focusedButtonIndex = nil
    return
  }
  if screenOwnsWorldInput() {
    handleMouseDown(x: lastMouseScreenX, y: lastMouseScreenY)
  }
}

@MainActor func activateReleased() {
  if screenOwnsWorldInput(), focusedButtonIndex == nil {
    handleMouseUp(x: lastMouseScreenX, y: lastMouseScreenY)
  }
}
