import SceneKit

/// A flat-shaded (hard-edged, faceted) triangle-mesh builder: each face is given as an ordered
/// list of 3+ coplanar vertices, fan-triangulated, with its own vertex copies so the normal is
/// constant across the face (no smooth shading) — matches the deliberately faceted low-poly look
/// used everywhere else in this tool (e.g. `BrickGeometry`'s octagonal studs).
enum FlatMesh {
  static func build(faces: [[SCNVector3]]) -> SCNGeometry {
    var positions: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var indices: [Int32] = []

    for face in faces {
      guard face.count >= 3 else { continue }
      let normal = faceNormal(face)
      let base = Int32(positions.count)
      positions.append(contentsOf: face)
      normals.append(contentsOf: Array(repeating: normal, count: face.count))
      for i in 1..<(face.count - 1) {
        indices.append(contentsOf: [base, base + Int32(i), base + Int32(i + 1)])
      }
    }

    let vertexSource = SCNGeometrySource(vertices: positions)
    let normalSource = SCNGeometrySource(normals: normals)
    let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
    return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
  }

  private static func faceNormal(_ face: [SCNVector3]) -> SCNVector3 {
    let a = face[0]
    let b = face[1]
    let c = face[2]
    let ab = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
    let ac = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
    let nx = ab.y * ac.z - ab.z * ac.y
    let ny = ab.z * ac.x - ab.x * ac.z
    let nz = ab.x * ac.y - ab.y * ac.x
    let len = max(0.0001, sqrt(nx * nx + ny * ny + nz * nz))
    return SCNVector3(nx / len, ny / len, nz / len)
  }
}

/// A wedge (right-angle triangular prism): full-height at the back edge (`-depth/2`), sloping
/// down to zero height at the front edge (`+depth/2`) — the roof-slope silhouette in Junkbot's
/// reference art. Origin is the wedge's bottom-back-center.
enum Wedge {
  static func geometry(width: CGFloat, depth: CGFloat, height: CGFloat) -> SCNGeometry {
    let w = Float(width) / 2
    let d = Float(depth) / 2
    let h = Float(height)

    // Bottom rectangle.
    let a = SCNVector3(-w, 0, -d)  // back-left
    let b = SCNVector3(w, 0, -d)  // back-right
    let c = SCNVector3(w, 0, d)  // front-right
    let dd = SCNVector3(-w, 0, d)  // front-left
    // Top back edge (front has zero height, so no top-front vertices).
    let e = SCNVector3(-w, h, -d)  // back-left top
    let f = SCNVector3(w, h, -d)  // back-right top

    return FlatMesh.build(faces: [
      [a, b, c, dd],  // bottom
      [a, e, f, b],  // back (vertical)
      [a, dd, e],  // left triangle
      [b, f, c],  // right triangle
      [dd, c, f, e],  // slope (top)
    ])
  }
}
