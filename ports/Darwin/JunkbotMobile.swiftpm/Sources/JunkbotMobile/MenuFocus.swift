import JunkbotCore

// Keyboard/d-pad menu focus navigation (Phase 7) - extracted from Input.swift since none of this
// touches SDL/GameController/etc. directly (it only calls into `menuButtons`/`gameEngine`/shared
// globals), so it's identical across every port (`ports/SDL3`, `ports/SDL2`, `ports/Darwin`).
// Each platform's own input code (SDL's `Input.swift`'s `GamepadState`, Darwin's
// `GamepadInput.swift`) just needs to call these in response to its own raw stick/button/key
// events. What stays platform-specific: raw stick/button polling, and `notePointingInput`'s
// OS-cursor show/hide call (still declared in each platform's own `Input.swift`-equivalent).

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
    hideOSCursor()
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
  warpCursor(x: lastMouseScreenX, y: lastMouseScreenY)
}

/// Activates the focused menu button if any; otherwise, hit-tests `menuButtons` at the cursor
/// position (mirroring a mouse-button-down's handling in each platform's own event loop) so a
/// virtual-cursor click on a button (stick-driven, no d-pad focus set - e.g. the title screen's
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
