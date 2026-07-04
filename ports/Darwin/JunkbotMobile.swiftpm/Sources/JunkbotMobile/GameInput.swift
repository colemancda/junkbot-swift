import JunkbotCore

// The parts of mouse/touch input handling that are 100% backend-neutral (only touch
// `gameEngine`/the camera globals, never a raw SDL/SpriteKit call) - shared across every port.
// Each platform's own input code (SDL's `Input.swift`, a future Darwin touch/mouse handler)
// converts its own native events into window/render-space coordinates, then calls into these.

/// Last known mouse position in world space, kept up to date by every mouse event so the cursor
/// (updated once per frame in the main loop, not per-event) always reflects the current hover
/// target even on frames with no new mouse event.
nonisolated(unsafe) var lastMouseWorldX: Int32 = 0
nonisolated(unsafe) var lastMouseWorldY: Int32 = 0

func handleMouseDown(x: Float, y: Float) {
  let world = gameEngine.canvasToWorld(
    canvasX: Double(x), canvasY: Double(y),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  lastMouseWorldX = Int32(world.x)
  lastMouseWorldY = Int32(world.y)
  gameEngine.mouseDown(lastMouseWorldX, lastMouseWorldY)
}

func handleMouseMove(x: Float, y: Float) {
  let world = gameEngine.canvasToWorld(
    canvasX: Double(x), canvasY: Double(y),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  lastMouseWorldX = Int32(world.x)
  lastMouseWorldY = Int32(world.y)
  gameEngine.mouseMove(lastMouseWorldX, lastMouseWorldY)
}

func handleMouseUp(x: Float, y: Float) {
  let world = gameEngine.canvasToWorld(
    canvasX: Double(x), canvasY: Double(y),
    centerX: cameraCenterX, centerY: cameraCenterY, scale: cameraScale,
    canvasWidth: Double(windowWidth), canvasHeight: Double(windowHeight))
  lastMouseWorldX = Int32(world.x)
  lastMouseWorldY = Int32(world.y)
  gameEngine.mouseUp(lastMouseWorldX, lastMouseWorldY)
}
