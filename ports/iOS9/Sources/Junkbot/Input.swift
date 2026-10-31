import JunkbotBackend
import JunkbotCore

// Gamepad input and input-kind-aware cursor visibility - the iOS 9 equivalent of the Darwin
// port's `GamepadInput.swift`, with the same bindings: A activates (`activatePressed`/
// `activateReleased`), the pause button backs out (`escapePressed`), the d-pad moves menu focus
// or nudges a grabbed brick (`directionPressed`), and the left stick moves the virtual cursor.
// MFi controllers are read through the backend, since Embedded Swift can't import
// GameController. iOS 9 has no `GCKeyboard`, so there's no keyboard input.

/// There's no OS cursor on iOS; the virtual cursor (`GameRender.swift`) stands in for gamepads.
func hideOSCursor() {}

func showOSCursor() {}

@GameActor func notePointingInput(_ kind: PointingInputKind) {
  guard kind != lastPointingInput else { return }
  lastPointingInput = kind
  switch kind {
  case .mouse:
    showOSCursor()
  case .gamepad, .touch:
    hideOSCursor()
  }
}

/// Moves the tracked cursor position; there's no real cursor to warp.
@GameActor func warpCursor(x: Float, y: Float) {
  lastMouseScreenX = x
  lastMouseScreenY = y
}

/// iOS 9 has no `GCKeyboard`.
@GameActor func configureKeyboardInput() {}

// MARK: - Gamepad

/// The most recently connected controller's buttons, plus per-frame left-stick polling that
/// moves the virtual cursor at constant velocity - as on the Darwin port.
@GameActor final class GamepadState {
  /// Fraction of full deflection below which the stick reads as centered (~24%), as on the
  /// other ports.
  private let deadzone: Float = 8000 / 32767
  /// Cursor speed at full stick deflection, in points per second.
  private let cursorSpeed: Float = 600

  init() {
    jb_gamepad_start { button, pressed in
      MainActor.assumeIsolated {
        GamepadState.buttonChanged(Int(button), pressed: pressed != 0)
      }
    }
  }

  private static func buttonChanged(_ button: Int, pressed: Bool) {
    switch button {
    case JB_GAMEPAD_A:
      if pressed {
        activatePressed()
      } else {
        activateReleased()
      }
    case JB_GAMEPAD_MENU:
      escapePressed()
    case JB_GAMEPAD_UP where pressed:
      directionPressed(dx: 0, dy: -1, menuDelta: -1)
    case JB_GAMEPAD_DOWN where pressed:
      directionPressed(dx: 0, dy: 1, menuDelta: 1)
    case JB_GAMEPAD_LEFT where pressed:
      directionPressed(dx: -1, dy: 0, menuDelta: -1)
    case JB_GAMEPAD_RIGHT where pressed:
      directionPressed(dx: 1, dy: 0, menuDelta: 1)
    default:
      break
    }
  }

  /// Reads the left stick and moves the tracked cursor position accordingly. Call once per
  /// frame. Only active on screens with a free-roaming cursor (gameplay and the title screen);
  /// menus are navigated by d-pad focus alone.
  func pollSticks(deltaSeconds: Float) {
    guard screenOwnsWorldInput() else { return }
    var axes: (Float, Float) = (0, 0)
    let hasStick = withUnsafeMutablePointer(to: &axes) {
      $0.withMemoryRebound(to: Float.self, capacity: 2) { jb_gamepad_left_stick($0) }
    }
    guard hasStick != 0 else { return }
    let x = abs(axes.0) > deadzone ? axes.0 : 0
    let y = abs(axes.1) > deadzone ? axes.1 : 0
    guard x != 0 || y != 0 else { return }
    notePointingInput(.gamepad)
    virtualCursorVisible = true

    // A cursor never touched starts at (-1, -1) - start from the window center instead.
    if lastMouseScreenX < 0 { lastMouseScreenX = Float(windowWidth) / 2 }
    if lastMouseScreenY < 0 { lastMouseScreenY = Float(windowHeight) / 2 }

    // GameController's +Y is up, the opposite of this project's Y-down screen space.
    let newX = max(0, min(Float(windowWidth) - 1, lastMouseScreenX + x * cursorSpeed * deltaSeconds))
    let newY = max(0, min(Float(windowHeight) - 1, lastMouseScreenY - y * cursorSpeed * deltaSeconds))
    warpCursor(x: newX, y: newY)
    handleMouseMove(x: newX, y: newY)
  }
}

/// Created on first use, from `JunkbotScene.update(_:)`.
@GameActor let gamepadState = GamepadState()
