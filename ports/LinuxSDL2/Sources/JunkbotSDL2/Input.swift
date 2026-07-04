import CSDL2
import Foundation
import JunkbotCore

// Gamepad + keyboard navigation and input-kind-aware cursor visibility (Phase 7). Design note:
// the gamepad's left stick moves the *real* OS cursor via SDL_WarpMouseInWindow, which
// generates ordinary SDL_MOUSEMOTION events - so every existing input path (world
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

/// Whether the gamepad-driven virtual cursor (`VirtualCursor.draw`, main.swift) should be drawn
/// right now - distinct from `lastPointingInput == .gamepad`, since d-pad *menu-focus*
/// navigation (as opposed to stick cursor movement or a brick nudge-drag) hides the cursor
/// entirely in favor of the focus ring, the same way it always hid the OS cursor before the
/// virtual cursor existed. Toggled alongside every `SDL_HideCursor`/`SDL_ShowCursor` call that's
/// about gamepad-driven visibility (`pollSticks`, `directionPressed`) - not by
/// `notePointingInput`, which only fires on an input *kind* change and would miss later
/// same-kind visibility changes (e.g. stick movement resuming after menu navigation hid it).
@MainActor var virtualCursorVisible = false

/// `SDL_TOUCH_MOUSEID`'s value - the macro is a C cast expression (`(SDL_MouseID)-1`) that
/// doesn't import into Swift. Mouse events synthesized from touch carry this `which` id;
/// filtering on it keeps them from flipping the input kind back to `.mouse`.
let touchMouseID: UInt32 = .max

/// Set right before every programmatic `SDL_WarpMouseInWindow` call (gamepad stick, d-pad
/// nudge) and consumed by the next `SDL_MOUSEMOTION`, so that one synthetic event isn't
/// mistaken for genuine mouse hardware movement (which must always show the cursor - see
/// `main.swift`'s motion handler).
@MainActor var suppressNextMouseMotionAsSynthetic = false

@MainActor func notePointingInput(_ kind: PointingInputKind) {
  guard kind != lastPointingInput else { return }
  lastPointingInput = kind
  switch kind {
  case .mouse:
    // Real hardware cursor - let the OS draw it (and `cursorSet.apply` swap its grab/grabbing
    // image), same as before.
    _ = SDL_ShowCursor()
  case .gamepad, .touch:
    // Gamepad drives a self-drawn virtual cursor (`VirtualCursor.draw`, main.swift) instead of
    // the OS cursor - some platforms (KMSDRM-backed Linux handhelds) have no hardware cursor
    // support at all, so the OS cursor must stay hidden while gamepad-driven, not just while
    // touch-driven.
    _ = SDL_HideCursor()
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
      SDL_GameControllerClose(existing)
    }
    gamepad = SDL_GameControllerOpen(joystickID)
  }

  func handleRemoved(_ joystickID: SDL_JoystickID) {
    // SDL2 has no direct "get instance ID from an open SDL_GameController" call - go through
    // its underlying SDL_Joystick.
    guard let gamepad, let joystick = SDL_GameControllerGetJoystick(gamepad),
      SDL_JoystickInstanceID(joystick) == joystickID
    else { return }
    SDL_GameControllerClose(gamepad)
    self.gamepad = nil
  }

  /// Reads the left stick and moves the tracked cursor position accordingly. Call once per
  /// frame. Only active on screens with a free-roaming cursor to point at (gameplay, and the
  /// title screen's draggable-bricks demo) - level select and the win/lose dialogs are
  /// navigated by d-pad focus alone, so stick motion is ignored there rather than fighting with
  /// focus navigation.
  ///
  /// Drives `lastMouseScreenX/Y` and `handleMouseMove` directly instead of routing through
  /// `SDL_GetMouseState`/`SDL_WarpMouseInWindow` and waiting for the resulting motion event:
  /// some platforms (KMSDRM-backed Linux, as on ARM64 handhelds with no mouse hardware at all)
  /// have no real pointing device, so `SDL_GetMouseState` never reflects prior warps (leaving
  /// the cursor stuck at its initial position) and the warp itself may be a no-op. The warp
  /// call below is kept as a best-effort sync for platforms that do have a real cursor, but
  /// nothing here depends on it succeeding.
  func pollSticks(deltaSeconds: Float) {
    guard let gamepad, screenOwnsWorldInput() else { return }
    let rawX = Float(SDL_GameControllerGetAxis(gamepad, SDL_CONTROLLER_AXIS_LEFTX)) / 32767
    let rawY = Float(SDL_GameControllerGetAxis(gamepad, SDL_CONTROLLER_AXIS_LEFTY)) / 32767
    let x = abs(rawX) > deadzone ? rawX : 0
    let y = abs(rawY) > deadzone ? rawY : 0
    guard x != 0 || y != 0 else { return }
    notePointingInput(.gamepad)
    virtualCursorVisible = true

    // A mouse-never-touched cursor starts at (-1, -1); on devices with no mouse hardware at
    // all, that's the only initial value it'll ever have - start from the window center
    // instead of clamping straight into a top-left corner.
    if lastMouseScreenX < 0 { lastMouseScreenX = Float(windowWidth) / 2 }
    if lastMouseScreenY < 0 { lastMouseScreenY = Float(windowHeight) / 2 }

    let newX = max(0, min(Float(windowWidth) - 1, lastMouseScreenX + x * cursorSpeed * deltaSeconds))
    let newY = max(0, min(Float(windowHeight) - 1, lastMouseScreenY + y * cursorSpeed * deltaSeconds))
    lastMouseScreenX = newX
    lastMouseScreenY = newY
    suppressNextMouseMotionAsSynthetic = true
    // SDL_WarpMouseInWindow takes window-space (point) coordinates, which differ from the
    // render-space units used everywhere else in this file once
    // SDL_LOGICAL_PRESENTATION_INTEGER_SCALE introduces letterboxing.
    let windowPoint = renderToWindowPoint(x: newX, y: newY)
    SDL_WarpMouseInWindow(window, Int32(windowPoint.x), Int32(windowPoint.y))
    handleMouseMove(x: newX, y: newY)
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
///
/// Cursor visibility differs between the two: nudging a brick keeps the cursor visible (it's
/// the drag handle - the player needs to see where it'll land), but menu/item navigation hides
/// it, since the focus ring is the indicator there and a static cursor left over a menu item
/// would be a confusing, meaningless leftover once you start moving focus with the d-pad/arrows.
@MainActor func directionPressed(dx: Int32, dy: Int32, menuDelta: Int) {
  if gameEngine.isDragging {
    notePointingInput(.gamepad)
    virtualCursorVisible = true
    nudgeDrag(dx: dx, dy: dy)
  } else {
    _ = SDL_HideCursor()
    virtualCursorVisible = false
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
  suppressNextMouseMotionAsSynthetic = true
  // SDL_WarpMouseInWindow takes window-space (point) coordinates, which differ from the
  // render-space units used everywhere else in this file once
  // SDL_LOGICAL_PRESENTATION_INTEGER_SCALE introduces letterboxing.
  let windowPoint = renderToWindowPoint(x: lastMouseScreenX, y: lastMouseScreenY)
  SDL_WarpMouseInWindow(window, Int32(windowPoint.x), Int32(windowPoint.y))
}

/// Activates the focused menu button if any; otherwise, hit-tests `menuButtons` at the cursor
/// position (mirroring `SDL_MOUSEBUTTONDOWN`'s handling in main.swift) so a virtual-
/// cursor click on a button (stick-driven, no d-pad focus set - e.g. the title screen's
/// Play/Credits buttons) actually activates it instead of falling through to a world click;
/// only once neither of those applies does A synthesize a mouse press/release at the cursor so
/// it can grab/release a brick with the exact mouse semantics (drag direction resolution,
/// canRelease-gated drops, toast dismissal).
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
  if handleClick(menuButtons, at: lastMouseScreenX, y: lastMouseScreenY) {
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
