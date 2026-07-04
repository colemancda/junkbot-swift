import SDL3Swift
import Foundation
import JunkbotCore

// Gamepad + keyboard navigation and input-kind-aware cursor visibility (Phase 7). Design note:
// the gamepad's left stick moves the *real* OS cursor via `window.warpMouse(to:)`, which
// generates ordinary mouse-motion events - so every existing input path (world drags, menu
// hover, the level-select rollover bar, grab cursors) works unchanged, and the A button just
// synthesizes the same code paths a mouse click takes.

// MARK: - Input-kind tracking (cursor visibility)
//
// `PointingInputKind` itself now lives in `Sources/JunkbotCore/PointingInputKind.swift`, shared
// with `ports/Darwin`'s `GameShell.swift`.

@MainActor var lastPointingInput: PointingInputKind = .mouse

/// Whether the gamepad-driven virtual cursor (`VirtualCursor.draw`, main.swift) should be drawn
/// right now - distinct from `lastPointingInput == .gamepad`, since d-pad *menu-focus*
/// navigation (as opposed to stick cursor movement or a brick nudge-drag) hides the cursor
/// entirely in favor of the focus ring, the same way it always hid the OS cursor before the
/// virtual cursor existed. Toggled alongside every cursor-visibility change that's about
/// gamepad-driven visibility (`pollSticks`, `directionPressed`) - not by `notePointingInput`,
/// which only fires on an input *kind* change and would miss later same-kind visibility changes
/// (e.g. stick movement resuming after menu navigation hid it).
@MainActor var virtualCursorVisible = false

/// Set right before every programmatic `window.warpMouse(to:)` call (gamepad stick, d-pad
/// nudge) and consumed by the next mouse-motion event, so that one synthetic event isn't
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
    SDL.isCursorVisible = true
  case .gamepad, .touch:
    // Gamepad drives a self-drawn virtual cursor (`VirtualCursor.draw`, main.swift) instead of
    // the OS cursor - some platforms (KMSDRM-backed Linux handhelds) have no hardware cursor
    // support at all, so the OS cursor must stay hidden while gamepad-driven, not just while
    // touch-driven.
    SDL.isCursorVisible = false
  }
}

// MARK: - Gamepad

/// One active controller (last plugged-in wins), with per-frame left-stick polling that moves
/// the cursor at constant velocity. Polling (rather than reacting to axis-motion events) gives
/// smooth movement independent of the event delivery rate.
@MainActor final class GamepadState {
  /// Reassigning this releases (and, via `SDLGamepad`'s own `deinit`, closes) any
  /// previously-open gamepad automatically - no manual close-before-open needed.
  private var gamepad: SDLGamepad?
  /// Fraction of full deflection below which the stick reads as centered (~24%).
  private let deadzone: Float = 8000 / 32767
  /// Cursor speed at full stick deflection, in window pixels per second.
  private let cursorSpeed: Float = 600

  func handleAdded(_ joystickID: JoystickID) {
    gamepad = try? SDLGamepad(joystickID: joystickID)
  }

  func handleRemoved(_ joystickID: JoystickID) {
    guard let gamepad, gamepad.id == joystickID else { return }
    self.gamepad = nil
  }

  /// Reads the left stick and moves the tracked cursor position accordingly. Call once per
  /// frame. Only active on screens with a free-roaming cursor to point at (gameplay, and the
  /// title screen's draggable-bricks demo) - level select and the win/lose dialogs are
  /// navigated by d-pad focus alone, so stick motion is ignored there rather than fighting with
  /// focus navigation.
  ///
  /// Drives `lastMouseScreenX/Y` and `handleMouseMove` directly instead of routing through
  /// `SDL_GetMouseState`/`warpMouse` and waiting for the resulting motion event: some platforms
  /// (KMSDRM-backed Linux, as on ARM64 handhelds with no mouse hardware at all) have no real
  /// pointing device, so querying mouse state never reflects prior warps (leaving the cursor
  /// stuck at its initial position) and the warp itself may be a no-op. The warp call below is
  /// kept as a best-effort sync for platforms that do have a real cursor, but nothing here
  /// depends on it succeeding.
  func pollSticks(deltaSeconds: Float) {
    guard let gamepad, screenOwnsWorldInput() else { return }
    let rawX = Float(gamepad.axis(.leftX)) / 32767
    let rawY = Float(gamepad.axis(.leftY)) / 32767
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
    warpCursor(x: newX, y: newY)
    handleMouseMove(x: newX, y: newY)
  }
}

// MARK: - Menu focus (keyboard / d-pad navigation)
//
// The portable logic (`focusedButtonIndex`, `moveFocus`, `directionPressed`, `nudgeDrag`,
// `activatePressed`, `activateReleased`) now lives in the shared, symlinked `MenuFocus.swift`
// (identical across `ports/SDL3`/`ports/SDL2`/`ports/Darwin`). It calls back into these two
// SDL-specific neutral wrappers instead of raw calls directly, the same pattern `main.swift`'s
// `currentTicksNanoseconds()`/`openExternalURL(_:)` already use.

/// Hides the OS cursor - called by `directionPressed` when d-pad/arrow input moves menu focus
/// (the focus ring is the indicator there, not the cursor).
func hideOSCursor() {
  SDL.isCursorVisible = false
}

/// Warps the real OS cursor to a render-space position and marks the next mouse-motion event as
/// synthetic (so it isn't mistaken for genuine mouse hardware movement) - called by `nudgeDrag`
/// after advancing the tracked mouse position by one grid cell.
@MainActor func warpCursor(x: Float, y: Float) {
  suppressNextMouseMotionAsSynthetic = true
  // `warpMouse` takes window-space (point) coordinates, which differ from the render-space
  // units used everywhere else in this file once `.integerScale` presentation introduces
  // letterboxing.
  let windowPoint = renderToWindowPoint(x: x, y: y)
  window.warpMouse(to: windowPoint)
}
