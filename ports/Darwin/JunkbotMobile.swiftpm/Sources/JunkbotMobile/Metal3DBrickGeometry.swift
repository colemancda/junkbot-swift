import Foundation
#if canImport(simd)
import simd
#endif

/// `Metal3D*`'s counterpart to `Scene3DBrickGeometry.swift`/`Scene3DEdgeOutline.swift`: the same
/// box-plus-stud-cylinders brick shape and black edge silhouette, as raw triangles instead of
/// `SCNBox`/`SCNCylinder`/`SCNGeometryElement(primitiveType: .line)` (the shared triangle pipeline
/// only draws triangles, so the outline is thin black boxes along each edge rather than true
/// `GL_LINES`-style geometry - visually equivalent at this scale).
@GameActor
enum Metal3DBrickGeometry {
  private static var cache: [Int64: [Metal3DVertex]] = [:]

  /// Local-space (centered on the brick's own origin, matching `Metal3DSpace.center(of:)`'s
  /// anchor convention) vertex list for a `studs`-wide brick of `colorIndex`'s color. Cached per
  /// (studs, color) pair and reused across every placement of that combination, same as
  /// `Scene3DBrickGeometry`'s node cache.
  static func vertices(widthInStuds studs: Int32, colorIndex: Int32) -> [Metal3DVertex] {
    let clamped = max(1, min(8, studs))
    let key = Int64(clamped) << 32 | Int64(colorIndex)
    if let cached = cache[key] { return cached }

    let width = Float(clamped) * Metal3DSpace.studW
    let height = Metal3DSpace.rowH
    let length = Metal3DSpace.depth
    let color = Metal3DPalette.brickColor(colorIndex: colorIndex)

    var verts = box(width: width, height: height, length: length, color: color)

    // 2 rows deep x `clamped` columns of studs on top - matches `Scene3DBrickGeometry` exactly.
    let studRowsDeep: Int32 = 2
    for row in 0..<studRowsDeep {
      let z = (Float(row) + 0.5) * Metal3DSpace.studW - Metal3DSpace.studW
      for i in 0..<clamped {
        let x = (Float(i) + 0.5) * Metal3DSpace.studW - width / 2
        let y = height / 2 + Metal3DSpace.studHeight / 2
        verts.append(
          contentsOf: cylinder(
            radius: Metal3DSpace.studRadius, height: Metal3DSpace.studHeight,
            segments: Metal3DSpace.studSegments, center: SIMD3<Float>(x, y, z),
            color: color))
      }
    }

    verts.append(contentsOf: edgeOutline(width: width, height: height, length: length))

    cache[key] = verts
    return verts
  }

  // MARK: - Primitives

  private static func box(width: Float, height: Float, length: Float, color: SIMD4<Float>)
    -> [Metal3DVertex]
  {
    let w = width / 2, h = height / 2, l = length / 2
    var verts: [Metal3DVertex] = []
    verts.reserveCapacity(36)

    func quad(
      _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>,
      normal: SIMD3<Float>
    ) {
      for p in [a, b, c, a, c, d] {
        verts.append(Metal3DVertex(position: p, normal: normal, color: color))
      }
    }

    quad(
      SIMD3(-w, -h, l), SIMD3(w, -h, l), SIMD3(w, h, l), SIMD3(-w, h, l), normal: SIMD3(0, 0, 1))
    quad(
      SIMD3(w, -h, -l), SIMD3(-w, -h, -l), SIMD3(-w, h, -l), SIMD3(w, h, -l),
      normal: SIMD3(0, 0, -1))
    quad(
      SIMD3(w, -h, l), SIMD3(w, -h, -l), SIMD3(w, h, -l), SIMD3(w, h, l), normal: SIMD3(1, 0, 0))
    quad(
      SIMD3(-w, -h, -l), SIMD3(-w, -h, l), SIMD3(-w, h, l), SIMD3(-w, h, -l),
      normal: SIMD3(-1, 0, 0))
    quad(
      SIMD3(-w, h, l), SIMD3(w, h, l), SIMD3(w, h, -l), SIMD3(-w, h, -l), normal: SIMD3(0, 1, 0))
    quad(
      SIMD3(-w, -h, -l), SIMD3(w, -h, -l), SIMD3(w, -h, l), SIMD3(-w, -h, l),
      normal: SIMD3(0, -1, 0))

    return verts
  }

  private static func cylinder(
    radius: Float, height: Float, segments: Int, center: SIMD3<Float>, color: SIMD4<Float>
  ) -> [Metal3DVertex] {
    var verts: [Metal3DVertex] = []
    let halfH = height / 2
    let angleStep = 2 * Float.pi / Float(segments)
    let topCenter = center + SIMD3<Float>(0, halfH, 0)
    let botCenter = center + SIMD3<Float>(0, -halfH, 0)

    for i in 0..<segments {
      let a0 = Float(i) * angleStep
      let a1 = Float(i + 1) * angleStep
      // `cos`/`sin` only have a `Double` overload via Glibc on Linux/Android - see
      // `Metal3DMatrix.swift`'s `rotationX`/`rotationY` for the same fix.
      let n0 = SIMD3<Float>(Float(cos(Double(a0))), 0, Float(sin(Double(a0))))
      let n1 = SIMD3<Float>(Float(cos(Double(a1))), 0, Float(sin(Double(a1))))
      let p0b = center + n0 * radius - SIMD3<Float>(0, halfH, 0)
      let p1b = center + n1 * radius - SIMD3<Float>(0, halfH, 0)
      let p0t = center + n0 * radius + SIMD3<Float>(0, halfH, 0)
      let p1t = center + n1 * radius + SIMD3<Float>(0, halfH, 0)

      verts.append(Metal3DVertex(position: p0b, normal: n0, color: color))
      verts.append(Metal3DVertex(position: p1b, normal: n1, color: color))
      verts.append(Metal3DVertex(position: p1t, normal: n1, color: color))
      verts.append(Metal3DVertex(position: p0b, normal: n0, color: color))
      verts.append(Metal3DVertex(position: p1t, normal: n1, color: color))
      verts.append(Metal3DVertex(position: p0t, normal: n0, color: color))

      verts.append(Metal3DVertex(position: topCenter, normal: SIMD3(0, 1, 0), color: color))
      verts.append(Metal3DVertex(position: p0t, normal: SIMD3(0, 1, 0), color: color))
      verts.append(Metal3DVertex(position: p1t, normal: SIMD3(0, 1, 0), color: color))

      verts.append(Metal3DVertex(position: botCenter, normal: SIMD3(0, -1, 0), color: color))
      verts.append(Metal3DVertex(position: p1b, normal: SIMD3(0, -1, 0), color: color))
      verts.append(Metal3DVertex(position: p0b, normal: SIMD3(0, -1, 0), color: color))
    }
    return verts
  }

  /// 12 thin black boxes along a brick's edges - see this file's doc comment for why boxes
  /// instead of true line geometry. Matches `Scene3DEdgeOutline.box`'s 1.5% inflation.
  private static func edgeOutline(width: Float, height: Float, length: Float) -> [Metal3DVertex] {
    let inflate: Float = 1.015
    let w = width * inflate / 2, h = height * inflate / 2, l = length * inflate / 2
    let corners: [SIMD3<Float>] = [
      SIMD3(-w, -h, -l), SIMD3(w, -h, -l), SIMD3(w, -h, l), SIMD3(-w, -h, l),
      SIMD3(-w, h, -l), SIMD3(w, h, -l), SIMD3(w, h, l), SIMD3(-w, h, l),
    ]
    let edges: [(Int, Int)] = [
      (0, 1), (1, 2), (2, 3), (3, 0),
      (4, 5), (5, 6), (6, 7), (7, 4),
      (0, 4), (1, 5), (2, 6), (3, 7),
    ]
    let thickness: Float = 0.6
    var verts: [Metal3DVertex] = []
    for (ia, ib) in edges {
      verts.append(contentsOf: edgeBox(corners[ia], corners[ib], thickness: thickness))
    }
    return verts
  }

  /// A thin box between two points that differ along exactly one axis (true of every box edge) -
  /// no rotation needed, just an axis-aligned box sized/centered to span `a`...`b`.
  private static func edgeBox(_ a: SIMD3<Float>, _ b: SIMD3<Float>, thickness: Float)
    -> [Metal3DVertex]
  {
    let mid = (a + b) / 2
    let d = b - a
    let w = abs(d.x) > 0.001 ? abs(d.x) : thickness
    let h = abs(d.y) > 0.001 ? abs(d.y) : thickness
    let l = abs(d.z) > 0.001 ? abs(d.z) : thickness
    return box(width: w, height: h, length: l, color: Metal3DPalette.outline).map {
      Metal3DVertex(position: $0.position + mid, normal: $0.normal, color: $0.color)
    }
  }
}
