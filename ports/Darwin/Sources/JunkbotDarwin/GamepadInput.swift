@preconcurrency import GameController
import JunkbotCore
#if os(macOS)
import AppKit
#endif

// Gamepad + keyboard navigation and input-kind-aware cursor visibility - the Darwin equivalent
// of `ports/SDL3/Sources/JunkbotSDL3/Input.swift` (Phase 7), built on `GameController.framework`
// instead of raw SDL calls. `GCController` covers gamepads and `GCKeyboard` covers physical
// keyboards uniformly across macOS/iOS/tvOS, so - unlike the SDL ports - there's no separate
// keyboard-event path to wire up. This is also what makes tvOS actually playable at all:
// `GameScene.swift`'s touch handlers never fire on tvOS (no touchscreen), so Siri Remote input
// (exposed as a `GCMicroGamepad`) is the *only* input path there.
//
// `focusedButtonIndex`/`moveFocus`/`directionPressed`/`nudgeDrag`/`activatePressed`/
// `activateReleased` themselves live in the shared, symlinked `MenuFocus.swift` (identical
// across `ports/SDL3`/`ports/SDL2`/`ports/Darwin`) - this file only provides the two neutral
// wrappers it calls back into (`hideOSCursor`/`warpCursor`, matching `main.swift`'s
// `currentTicksNanoseconds`/`openExternalURL` pattern) plus the actual raw stick/button/key
// event handling that drives them.

/// Hides the OS cursor - macOS only (`NSCursor`, balanced `hide()`/`unhide()` calls gated on an
/// actual kind change, same as SDL's `SDL_HideCursor`/`SDL_ShowCursor`); no-op on iOS/tvOS, where
/// there's no meaningful OS cursor to manage - the shared virtual-cursor drawing in
/// `GameRender.swift`'s `render()` (`lastPointingInput == .gamepad` branch) takes over instead
/// once `lastPointingInput`/`virtualCursorVisible` are driven correctly, which already works
/// today with zero new drawing code.
func hideOSCursor() {
  #if os(macOS)
  NSCursor.hide()
  #endif
}

func showOSCursor() {
  #if os(macOS)
  NSCursor.unhide()
  #endif
}

@MainActor func notePointingInput(_ kind: PointingInputKind) {
  guard kind != lastPointingInput else { return }
  lastPointingInput = kind
  switch kind {
  case .mouse:
    showOSCursor()
  case .gamepad, .touch:
    hideOSCursor()
  }
}

/// Moves the tracked cursor position directly - unlike SDL's `SDL_WarpMouseInWindow`, there's no
/// real OS cursor to warp on iOS/tvOS, and warping the actual mouse position on macOS isn't
/// available to an ordinary app anyway. `lastMouseScreenX/Y` (read by `GameRender.swift`'s
/// virtual-cursor draw and `GameInput.swift`'s coordinate math) is the only "cursor" that needs
/// to move here.
@MainActor func warpCursor(x: Float, y: Float) {
  lastMouseScreenX = x
  lastMouseScreenY = y
}

// MARK: - Gamepad

/// One active controller (last-connected wins), with per-frame left-stick polling that moves
/// the virtual cursor at constant velocity - mirrors `ports/SDL3`'s `GamepadState` exactly,
/// built on `GCController`/`GCExtendedGamepad` instead of raw SDL calls. Falls back to
/// `GCMicroGamepad` (dpad + one button) when `extendedGamepad` is `nil` - the profile tvOS's
/// Siri Remote actually exposes.
@MainActor final class GamepadState {
  private var controller: GCController?
  /// Fraction of full deflection below which the stick reads as centered (~24%) - same value
  /// `ports/SDL3`'s `GamepadState` uses.
  private let deadzone: Float = 8000 / 32767
  /// Cursor speed at full stick deflection, in points per second.
  private let cursorSpeed: Float = 600

  init() {
    // `queue: .main` guarantees these closures run on the main thread. `GameController` isn't
    // yet Swift-6-audited for `Sendable`, hence the `@preconcurrency import` above - without it,
    // capturing a `GCController` across this closure boundary is flagged as a potential data
    // race even though it can't actually race here.
    NotificationCenter.default.addObserver(
      forName: .GCControllerDidConnect, object: nil, queue: .main
    ) { [weak self] notification in
      guard let controller = notification.object as? GCController else { return }
      self?.attach(controller)
    }
    NotificationCenter.default.addObserver(
      forName: .GCControllerDidDisconnect, object: nil, queue: .main
    ) { [weak self] notification in
      guard let controller = notification.object as? GCController else { return }
      self?.detach(controller)
    }
    // Pick up any controller that connected before this initializer ran.
    if let existing = GCController.controllers().last {
      attach(existing)
    }
  }

  private func attach(_ controller: GCController) {
    self.controller = controller

    let activateButton: GCControllerButtonInput?
    let menuButton: GCControllerButtonInput?
    let dpad: GCControllerDirectionPad?
    if let extended = controller.extendedGamepad {
      activateButton = extended.buttonA
      menuButton = extended.buttonMenu
      dpad = extended.dpad
    } else if let micro = controller.microGamepad {
      activateButton = micro.buttonA
      // `GCMicroGamepad.buttonMenu` (the Siri Remote's Menu button) requires tvOS 13+ - fine
      // given this project's existing deployment targets, but flagging since it's newer than
      // `buttonA`/`dpad` (available since tvOS 9).
      menuButton = micro.buttonMenu
      dpad = micro.dpad
    } else {
      activateButton = nil
      menuButton = nil
      dpad = nil
    }

    activateButton?.pressedChangedHandler = { _, _, pressed in
      Task { @MainActor in
        if pressed {
          activatePressed()
        } else {
          activateReleased()
        }
      }
    }
    menuButton?.pressedChangedHandler = { _, _, pressed in
      guard pressed else { return }
      Task { @MainActor in escapePressed() }
    }
    dpad?.up.pressedChangedHandler = { _, _, pressed in
      guard pressed else { return }
      Task { @MainActor in directionPressed(dx: 0, dy: -1, menuDelta: -1) }
    }
    dpad?.down.pressedChangedHandler = { _, _, pressed in
      guard pressed else { return }
      Task { @MainActor in directionPressed(dx: 0, dy: 1, menuDelta: 1) }
    }
    dpad?.left.pressedChangedHandler = { _, _, pressed in
      guard pressed else { return }
      Task { @MainActor in directionPressed(dx: -1, dy: 0, menuDelta: -1) }
    }
    dpad?.right.pressedChangedHandler = { _, _, pressed in
      guard pressed else { return }
      Task { @MainActor in directionPressed(dx: 1, dy: 0, menuDelta: 1) }
    }
  }

  private func detach(_ controller: GCController) {
    guard controller === self.controller else { return }
    self.controller = nil
  }

  /// Reads the left stick (or the Siri Remote's touch-surface dpad, read as an analog stick via
  /// `GCMicroGamepad.dpad`) and moves the tracked cursor position accordingly. Call once per
  /// frame. Only active on screens with a free-roaming cursor to point at (gameplay, and the
  /// title screen's draggable-bricks demo) - level select and the win/lose dialogs are navigated
  /// by d-pad focus alone, so stick motion is ignored there rather than fighting with focus
  /// navigation.
  func pollSticks(deltaSeconds: Float) {
    guard screenOwnsWorldInput() else { return }
    let rawX: Float
    let rawY: Float
    if let extended = controller?.extendedGamepad {
      rawX = extended.leftThumbstick.xAxis.value
      rawY = extended.leftThumbstick.yAxis.value
    } else if let micro = controller?.microGamepad {
      rawX = micro.dpad.xAxis.value
      rawY = micro.dpad.yAxis.value
    } else {
      return
    }
    let x = abs(rawX) > deadzone ? rawX : 0
    let y = abs(rawY) > deadzone ? rawY : 0
    guard x != 0 || y != 0 else { return }
    notePointingInput(.gamepad)
    virtualCursorVisible = true

    // A cursor never touched by the mouse starts at (-1, -1) - start from the window center
    // instead of clamping straight into a top-left corner.
    if lastMouseScreenX < 0 { lastMouseScreenX = Float(windowWidth) / 2 }
    if lastMouseScreenY < 0 { lastMouseScreenY = Float(windowHeight) / 2 }

    // GameController's axis Y convention is +1 = up (documented), the opposite of this
    // project's Y-down screen space (matching SDL's own +1 = down convention) - negate to match.
    let newX = max(0, min(Float(windowWidth) - 1, lastMouseScreenX + x * cursorSpeed * deltaSeconds))
    let newY = max(0, min(Float(windowHeight) - 1, lastMouseScreenY - y * cursorSpeed * deltaSeconds))
    warpCursor(x: newX, y: newY)
    handleMouseMove(x: newX, y: newY)
  }
}

/// Constructed once from `JunkbotScene.didMove(to:)` alongside `configureGameEngineCallbacks()`.
@MainActor let gamepadState = GamepadState()

// MARK: - Keyboard

/// Wires physical-keyboard arrow/space/return/escape input to the same shared menu-navigation
/// functions the gamepad d-pad/buttons use, via `GCKeyboard` (covers macOS/iOS/tvOS uniformly -
/// no separate `NSEvent`/`UIKeyCommand` path needed). Call once, from `JunkbotScene.didMove(to:)`.
@MainActor func configureKeyboardInput() {
  GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = { _, _, keyCode, pressed in
    Task { @MainActor in
      guard pressed else {
        if keyCode == .spacebar || keyCode == .returnOrEnter {
          activateReleased()
        }
        return
      }
      switch keyCode {
      case .upArrow: directionPressed(dx: 0, dy: -1, menuDelta: -1)
      case .downArrow: directionPressed(dx: 0, dy: 1, menuDelta: 1)
      case .leftArrow: directionPressed(dx: -1, dy: 0, menuDelta: -1)
      case .rightArrow: directionPressed(dx: 1, dy: 0, menuDelta: 1)
      case .spacebar, .returnOrEnter: activatePressed()
      case .escape: escapePressed()
      default: break
      }
    }
  }
}
