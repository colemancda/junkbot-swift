/// World<->canvas coordinate conversion. Pure functions of the caller-supplied viewport/canvas
/// values (not `GameEngine`'s own `viewportCenterX/Y/Scale`, which are `Int32`-typed and unused
/// by JS's viewport today — JS's `viewport.centerX/Y` can be fractional mid-zoom/pan, so routing
/// through the integer fields would lose precision). JS still owns the actual `viewport`/`canvas`
/// globals and passes their current values in on every call.
extension GameEngine {

  public struct CanvasPoint {
    public var x: Double
    public var y: Double
  }

  public func worldToCanvas(
    worldX: Double, worldY: Double,
    centerX: Double, centerY: Double, scale: Double,
    canvasWidth: Double, canvasHeight: Double
  ) -> CanvasPoint {
    CanvasPoint(
      x: (worldX - centerX) * scale + (canvasWidth / 2).rounded(.down),
      y: (worldY - centerY) * scale + (canvasHeight / 2).rounded(.down)
    )
  }

  public func canvasToWorld(
    canvasX: Double, canvasY: Double,
    centerX: Double, centerY: Double, scale: Double,
    canvasWidth: Double, canvasHeight: Double
  ) -> CanvasPoint {
    CanvasPoint(
      x: (canvasX - (canvasWidth / 2).rounded(.down)) / scale + centerX,
      y: (canvasY - (canvasHeight / 2).rounded(.down)) / scale + centerY
    )
  }
}
