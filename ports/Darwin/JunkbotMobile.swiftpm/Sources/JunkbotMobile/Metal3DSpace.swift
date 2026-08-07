import JunkbotCore
#if canImport(simd)
import simd
#endif

/// `Metal3D*`'s counterpart to `Scene3DSpace.swift` - same game-pixel-to-scene-unit mapping (+x
/// right, +y **down** in the game, flipped to +y **up** here), expressed in `simd` types instead
/// of SceneKit's, so the Metal path stays fully decoupled from anything SceneKit-adjacent. Keep in
/// sync with `Scene3DSpace.swift`/`tools/Junkbot3D/Sources/Junkbot3D/Space.swift` if either changes.
enum Metal3DSpace {
  static let studW = Float(CELL_W)  // 15: one stud, horizontally
  static let rowH = Float(CELL_H)  // 18: one brick row, vertically
  static let depth = Float(CELL_W) * 2  // the level is 2 studs deep, front-to-back

  static let studRadius: Float = 4.4
  static let studHeight: Float = 3.0
  static let studSegments = 8

  /// Scene-space center of an entity's bounding box - matches `Scene3DSpace.center(of:)` exactly.
  static func center(of e: Entity) -> SIMD3<Float> {
    let cx = Float(e.x) + Float(e.width) / 2
    let cy = Float(e.y) + Float(e.height) / 2
    return SIMD3<Float>(cx, -cy, 0)
  }
}
