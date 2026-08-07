import SceneKit

/// Real per-edge silhouette outlining, the technique real-time LDraw viewers (e.g. LDView) use
/// for the authentic "every LEGO edge has a black line" look: thin dark `GL_LINES`-style geometry
/// traced along a shape's hard edges, layered on top of the shaded surface, rather than baked into
/// a texture or approximated by a single bottom seam.
enum EdgeOutline {
  /// The 12-edge wireframe of an axis-aligned box, centered on the same origin as an
  /// `SCNBox(width:height:length:)` of the same dimensions — add as a child node at position
  /// zero. Slightly inflated (1.5%) so the lines clear the box's own surface without z-fighting.
  static func box(width: CGFloat, height: CGFloat, length: CGFloat) -> SCNNode {
    let inflate: CGFloat = 1.015
    let w = Float(width * inflate) / 2
    let h = Float(height * inflate) / 2
    let l = Float(length * inflate) / 2

    let corners: [SCNVector3] = [
      SCNVector3(-w, -h, -l), SCNVector3(w, -h, -l), SCNVector3(w, -h, l), SCNVector3(-w, -h, l),
      SCNVector3(-w, h, -l), SCNVector3(w, h, -l), SCNVector3(w, h, l), SCNVector3(-w, h, l),
    ]
    let edges: [(Int32, Int32)] = [
      (0, 1), (1, 2), (2, 3), (3, 0),  // bottom loop
      (4, 5), (5, 6), (6, 7), (7, 4),  // top loop
      (0, 4), (1, 5), (2, 6), (3, 7),  // verticals
    ]

    return lineNode(vertices: corners, edges: edges)
  }

  private static func lineNode(vertices: [SCNVector3], edges: [(Int32, Int32)]) -> SCNNode {
    var indices: [Int32] = []
    for (a, b) in edges { indices.append(contentsOf: [a, b]) }

    let source = SCNGeometrySource(vertices: vertices)
    let element = SCNGeometryElement(indices: indices, primitiveType: .line)
    let geometry = SCNGeometry(sources: [source], elements: [element])

    let material = SCNMaterial()
    material.diffuse.contents = NSColor.black
    material.lightingModel = .constant  // unlit: reads as pure black regardless of scene lighting
    geometry.firstMaterial = material

    return SCNNode(geometry: geometry)
  }
}
