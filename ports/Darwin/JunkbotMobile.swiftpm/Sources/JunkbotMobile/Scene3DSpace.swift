import JunkbotCore
import SceneKit

/// Maps the game's 2D world (pixels, +x right, +y **down**) into SceneKit's 3D space
/// (+x right, +y **up**, +z toward camera). 1 game pixel = 1 scene unit, so a stud is `CELL_W`
/// (15) units wide and a brick row is `CELL_H` (18) units tall — the game's exact grid, which also
/// happens to preserve LEGO's real 5:6 stud-width:brick-height ratio. Ported from
/// `tools/Junkbot3D/Sources/Junkbot3D/Space.swift` (the offline preview tool this mode's assets
/// and math were prototyped in) — keep the two in sync if either changes.
enum Scene3DSpace {
  static let studW = CGFloat(CELL_W)  // 15: one stud, horizontally
  static let rowH = CGFloat(CELL_H)  // 18: one brick row, vertically
  static let depth = CGFloat(CELL_W) * 2  // the level is 2 studs deep, front-to-back

  /// Low-poly stud dimensions (LEGO stud ≈ 12 LDU across, 4 tall, scaled to a 15u stud).
  static let studRadius = CGFloat(4.4)
  static let studHeight = CGFloat(3.0)
  /// Octagonal cylinders — enough facets to read as round at this scale, few enough for the
  /// deliberately faceted PS1/DS silhouette.
  static let studSegments = 8

  /// Scene-space center of an entity's bounding box. Game y is flipped (negated) so the level
  /// isn't upside-down; depth is centered on z=0 (bricks extend ±depth/2).
  static func center(of e: Entity) -> SCNVector3 {
    let cx = CGFloat(e.x) + CGFloat(e.width) / 2
    let cy = CGFloat(e.y) + CGFloat(e.height) / 2
    return SCNVector3(cx, -cy, 0)
  }
}
