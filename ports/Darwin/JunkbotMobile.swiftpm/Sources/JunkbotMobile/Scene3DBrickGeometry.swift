import JunkbotCore
import SceneKit

/// Builds and caches low-poly LEGO brick nodes. A brick is just a box (`widthInStuds` studs wide,
/// one row tall, `Scene3DSpace.depth` = 2 studs deep) with a `widthInStuds` x 2 grid of octagonal
/// studs on top — the ideal procedural asset: no source files, exact game dimensions, and the
/// faceted studs give the PS1/DS look. Ported from
/// `tools/Junkbot3D/Sources/Junkbot3D/BrickGeometry.swift`.
@MainActor
enum Scene3DBrickGeometry {
  /// Cache key: bricks with the same width+color share one geometry template, cloned per instance.
  private struct Key: Hashable {
    let studs: Int32
    let color: Int32
  }
  private static var cache: [Key: SCNNode] = [:]

  /// A node positioned so its origin is the brick's *center* (matches `Scene3DSpace.center`).
  /// Clone the returned node per placement (SceneKit shares the underlying geometry between
  /// clones).
  static func node(widthInStuds: Int32, colorIndex: Int32) -> SCNNode {
    let studs = max(1, min(8, widthInStuds))
    let key = Key(studs: studs, color: colorIndex)
    if let cached = cache[key] { return cached.clone() }

    let width = CGFloat(studs) * Scene3DSpace.studW
    let body = SCNBox(
      width: width, height: Scene3DSpace.rowH, length: Scene3DSpace.depth, chamferRadius: 0)
    body.firstMaterial = Scene3DPalette.material(Scene3DPalette.brickColor(colorIndex: colorIndex))
    let brick = SCNNode(geometry: body)

    // Full silhouette outline (every hard edge, LDView-style) rather than just a bottom seam, so
    // stacked bricks read as separate pieces and each brick's full outline matches the original
    // 2D sprite art.
    brick.addChildNode(
      Scene3DEdgeOutline.box(width: width, height: Scene3DSpace.rowH, length: Scene3DSpace.depth))

    // A studs-wide x 2-studs-deep grid on the top face (the level is 2 studs deep front-to-back).
    let studMat = body.firstMaterial!
    let studRowsDeep = 2
    for row in 0..<studRowsDeep {
      let rowCenterZ = (CGFloat(row) + 0.5) * Scene3DSpace.studW - Scene3DSpace.depth / 2
      for i in 0..<Int(studs) {
        let stud = SCNCylinder(radius: Scene3DSpace.studRadius, height: Scene3DSpace.studHeight)
        stud.radialSegmentCount = Scene3DSpace.studSegments
        stud.firstMaterial = studMat
        let studNode = SCNNode(geometry: stud)
        let colCenterX = (CGFloat(i) + 0.5) * Scene3DSpace.studW - width / 2
        studNode.position = SCNVector3(
          colCenterX, Scene3DSpace.rowH / 2 + Scene3DSpace.studHeight / 2, rowCenterZ)
        brick.addChildNode(studNode)
      }
    }

    cache[key] = brick
    return brick.clone()
  }
}
