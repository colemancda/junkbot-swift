import SceneKit
import simd

#if canImport(UIKit)
  import UIKit
  typealias PlatformColor = UIColor
#else
  import AppKit
  typealias PlatformColor = NSColor
#endif

// MARK: - Colors

/// An 8-bit RGB color, authored the same way the DS models are (hex per channel). The shared
/// palette below matches `ports/NDS/source/Models.swift` so a model dialed in here reads identically
/// there.
struct RGB: Hashable, Sendable {
  var r: Int
  var g: Int
  var b: Int
  init(_ r: Int, _ g: Int, _ b: Int) {
    self.r = r
    self.g = g
    self.b = b
  }
  var platformColor: PlatformColor {
    PlatformColor(
      red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
  }
}

extension RGB {
  static let red = RGB(0xC4, 0x28, 0x1C)
  static let orange = RGB(0xE8, 0x7A, 0x1E)
  static let yellow = RGB(0xF4, 0xC4, 0x14)
  static let green = RGB(0x2C, 0x8C, 0x3C)
  static let blue = RGB(0x3A, 0x8A, 0xC0)
  static let gray = RGB(0x9A, 0x9A, 0x9A)
  static let darkGray = RGB(0x54, 0x54, 0x54)
  static let tan = RGB(0xC8, 0x96, 0x50)
  static let brown = RGB(0x7A, 0x50, 0x28)
  static let white = RGB(0xF0, 0xF0, 0xF0)
  static let dark = RGB(0x22, 0x22, 0x22)
  static let cyan = RGB(0x40, 0xC0, 0xD0)
  static let purple = RGB(0x9A, 0x50, 0xC0)
  static let lightPurple = RGB(0xC4, 0x8A, 0xE0)
  static let flame = RGB(0xE0, 0x40, 0x10)
  static let flameInner = RGB(0xF4, 0x94, 0x14)
  static let pipe = RGB(0x6A, 0x8A, 0x9A)
  // Brick palette (0-4 map to the game's draggable colors).
  static let brickWhite = RGB(0xF4, 0xF4, 0xF4)
  static let brickBlue = RGB(0x1C, 0x54, 0xA8)
}

// MARK: - Mesh accumulation

typealias P3 = (Double, Double, Double)

/// Accumulates triangles grouped by color as a primitive emits them; `makeNode` then turns each
/// color group into one SceneKit geometry + material.
final class MeshData {
  private var positions: [RGB: [SCNVector3]] = [:]
  private var normals: [RGB: [SCNVector3]] = [:]

  func triangle(_ color: RGB, _ a: P3, _ b: P3, _ c: P3, normal n: P3) {
    let nrm = normalizedVector(n)
    positions[color, default: []].append(contentsOf: [scn(a), scn(b), scn(c)])
    normals[color, default: []].append(contentsOf: [nrm, nrm, nrm])
  }

  func quad(_ color: RGB, _ a: P3, _ b: P3, _ c: P3, _ d: P3, normal n: P3) {
    triangle(color, a, b, c, normal: n)
    triangle(color, a, c, d, normal: n)
  }

  // `SCNVector3`'s components are `Float` on iOS (this playground's target), so convert from the
  // `Double` authoring tuples explicitly.
  private func scn(_ p: P3) -> SCNVector3 {
    SCNVector3(Float(p.0), Float(p.1), Float(p.2))
  }

  private func normalizedVector(_ n: P3) -> SCNVector3 {
    let len = (n.0 * n.0 + n.1 * n.1 + n.2 * n.2).squareRoot()
    guard len > 0 else { return SCNVector3(0, 1, 0) }
    return SCNVector3(Float(n.0 / len), Float(n.1 / len), Float(n.2 / len))
  }

  func makeNode() -> SCNNode {
    let root = SCNNode()
    for (color, verts) in positions {
      guard let norms = normals[color], !verts.isEmpty else { continue }
      let vSource = SCNGeometrySource(vertices: verts)
      let nSource = SCNGeometrySource(normals: norms)
      let indices = (0..<verts.count).map { Int32($0) }
      let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
      let geometry = SCNGeometry(sources: [vSource, nSource], elements: [element])
      let material = SCNMaterial()
      material.lightingModel = .lambert
      material.diffuse.contents = color.platformColor
      material.locksAmbientWithDiffuse = true
      // The primitives don't emit a consistent counterclockwise winding, so render both sides
      // rather than let SceneKit back-face-cull the "wrong"-wound triangles (which would show the
      // dark background through them). Matches the DS renderer's `POLY_CULL_NONE`.
      material.isDoubleSided = true
      geometry.firstMaterial = material
      root.addChildNode(SCNNode(geometry: geometry))
    }
    return root
  }
}

// MARK: - Primitives

/// One authored shape. `emit(into:)` appends its triangles to the mesh - the whole DSL is just a
/// list of these, gathered by `@MeshBuilder`. `Sendable` so `Model` (and the `static let model`s in
/// each file) satisfy Swift 6 concurrency checking; every conforming primitive is a value type of
/// `Double`/`RGB` fields.
protocol MeshPrimitive: Sendable {
  func emit(into mesh: MeshData)
}

private let octagon: [(Double, Double)] = {
  let c = 0.7071067811865476
  return [(1, 0), (c, c), (0, 1), (-c, c), (-1, 0), (-c, -c), (0, -1), (c, -c)]
}()

/// An axis-aligned box. `center` and `half` (half-extents) are in stud units (1 unit = 1 LEGO
/// stud), matching the DS builder's `box(cx,cy,cz, hx,hy,hz)`.
struct Box: MeshPrimitive {
  var center: P3
  var half: P3
  var color: RGB
  func emit(into m: MeshData) {
    let (cx, cy, cz) = center
    let (hx, hy, hz) = half
    let x0 = cx - hx, x1 = cx + hx, y0 = cy - hy, y1 = cy + hy, z0 = cz - hz, z1 = cz + hz
    m.quad(color, (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), normal: (0, 0, 1))
    m.quad(color, (x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0), normal: (0, 0, -1))
    m.quad(color, (x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), normal: (1, 0, 0))
    m.quad(color, (x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0), normal: (-1, 0, 0))
    m.quad(color, (x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0), normal: (0, 1, 0))
    m.quad(color, (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), normal: (0, -1, 0))
  }
}

/// A LEGO stud: an octagonal cylinder (side ring + top cap, no bottom cap since it sits on a
/// brick). `at` is the (x, z) center on the brick top; `baseY` is the top surface it grows from.
struct Stud: MeshPrimitive {
  var at: (Double, Double)
  var baseY: Double
  var radius: Double
  var height: Double
  var color: RGB
  func emit(into m: MeshData) {
    let (cx, cz) = at
    let topY = baseY + height
    for i in 0..<8 {
      let (dx0, dz0) = octagon[i]
      let (dx1, dz1) = octagon[(i + 1) % 8]
      let p0 = (cx + dx0 * radius, cz + dz0 * radius)
      let p1 = (cx + dx1 * radius, cz + dz1 * radius)
      let n = ((dx0 + dx1) * 0.5, 0.0, (dz0 + dz1) * 0.5)
      m.quad(
        color, (p0.0, baseY, p0.1), (p1.0, baseY, p1.1), (p1.0, topY, p1.1), (p0.0, topY, p0.1),
        normal: n)
      m.triangle(
        color, (cx, topY, cz), (p0.0, topY, p0.1), (p1.0, topY, p1.1), normal: (0, 1, 0))
    }
  }
}

/// A vertical octagonal cylinder (axis along Y) with top and bottom caps - trash bins, spring
/// coils, fan hubs.
struct CylinderY: MeshPrimitive {
  var center: P3
  var radius: Double
  var halfHeight: Double
  var color: RGB
  func emit(into m: MeshData) {
    let (cx, cy, cz) = center
    let y0 = cy - halfHeight, y1 = cy + halfHeight
    for i in 0..<8 {
      let (dx0, dz0) = octagon[i]
      let (dx1, dz1) = octagon[(i + 1) % 8]
      let p0 = (cx + dx0 * radius, cz + dz0 * radius)
      let p1 = (cx + dx1 * radius, cz + dz1 * radius)
      let n = ((dx0 + dx1) * 0.5, 0.0, (dz0 + dz1) * 0.5)
      m.quad(
        color, (p0.0, y0, p0.1), (p1.0, y0, p1.1), (p1.0, y1, p1.1), (p0.0, y1, p0.1), normal: n)
      m.triangle(color, (cx, y1, cz), (p0.0, y1, p0.1), (p1.0, y1, p1.1), normal: (0, 1, 0))
      m.triangle(color, (cx, y0, cz), (p1.0, y0, p1.1), (p0.0, y0, p0.1), normal: (0, -1, 0))
    }
  }
}

/// A horizontal octagonal cylinder (axis along X) with end caps - pipes.
struct CylinderX: MeshPrimitive {
  var center: P3
  var radius: Double
  var halfLength: Double
  var color: RGB
  func emit(into m: MeshData) {
    let (cx, cy, cz) = center
    let x0 = cx - halfLength, x1 = cx + halfLength
    for i in 0..<8 {
      let (dy0, dz0) = octagon[i]
      let (dy1, dz1) = octagon[(i + 1) % 8]
      let p0 = (cy + dy0 * radius, cz + dz0 * radius)
      let p1 = (cy + dy1 * radius, cz + dz1 * radius)
      let n = (0.0, (dy0 + dy1) * 0.5, (dz0 + dz1) * 0.5)
      m.quad(
        color, (x0, p0.0, p0.1), (x1, p0.0, p0.1), (x1, p1.0, p1.1), (x0, p1.0, p1.1), normal: n)
      m.triangle(color, (x1, cy, cz), (x1, p0.0, p0.1), (x1, p1.0, p1.1), normal: (1, 0, 0))
      m.triangle(color, (x0, cy, cz), (x0, p1.0, p1.1), (x0, p0.0, p0.1), normal: (-1, 0, 0))
    }
  }
}

/// A flat octagonal disc facing +Z (a thin coin) - gearbot gears, eyebot eyes, badges.
struct Disc: MeshPrimitive {
  var center: P3
  var radius: Double
  var color: RGB
  func emit(into m: MeshData) {
    let (cx, cy, cz) = center
    for i in 0..<8 {
      let (dx0, dy0) = octagon[i]
      let (dx1, dy1) = octagon[(i + 1) % 8]
      m.triangle(
        color, (cx, cy, cz), (cx + dx0 * radius, cy + dy0 * radius, cz),
        (cx + dx1 * radius, cy + dy1 * radius, cz), normal: (0, 0, 1))
    }
  }
}

/// An octagonal cone (base ring up to an apex) - flames.
struct Cone: MeshPrimitive {
  var base: P3
  var radius: Double
  var height: Double
  var color: RGB
  func emit(into m: MeshData) {
    let (cx, baseY, cz) = base
    let apex = (cx, baseY + height, cz)
    for i in 0..<8 {
      let (dx0, dz0) = octagon[i]
      let (dx1, dz1) = octagon[(i + 1) % 8]
      let p0 = (cx + dx0 * radius, baseY, cz + dz0 * radius)
      let p1 = (cx + dx1 * radius, baseY, cz + dz1 * radius)
      let n = ((dx0 + dx1) * 0.4, 0.6, (dz0 + dz1) * 0.4)
      m.triangle(color, p0, p1, apex, normal: n)
    }
  }
}

// MARK: - Result builder + Model

@resultBuilder
enum MeshBuilder {
  static func buildBlock(_ components: [any MeshPrimitive]...) -> [any MeshPrimitive] {
    components.flatMap { $0 }
  }
  static func buildExpression(_ expression: any MeshPrimitive) -> [any MeshPrimitive] {
    [expression]
  }
  static func buildArray(_ components: [[any MeshPrimitive]]) -> [any MeshPrimitive] {
    components.flatMap { $0 }
  }
  static func buildOptional(_ component: [any MeshPrimitive]?) -> [any MeshPrimitive] {
    component ?? []
  }
  static func buildEither(first component: [any MeshPrimitive]) -> [any MeshPrimitive] { component }
  static func buildEither(second component: [any MeshPrimitive]) -> [any MeshPrimitive] { component }
}

/// A named 3D model authored in the DSL. `Model("Bin") { CylinderY(...); ... }`.
struct Model: Identifiable, Sendable {
  let id = UUID()
  let name: String
  let primitives: [any MeshPrimitive]

  init(_ name: String, @MeshBuilder _ content: () -> [any MeshPrimitive]) {
    self.name = name
    self.primitives = content()
  }

  /// The SceneKit node for this model (one geometry per color).
  func makeNode() -> SCNNode {
    let mesh = MeshData()
    for primitive in primitives { primitive.emit(into: mesh) }
    return mesh.makeNode()
  }

  var triangleCount: Int {
    let mesh = MeshData()
    for primitive in primitives { primitive.emit(into: mesh) }
    // Count via a fresh node's geometry element counts.
    return mesh.makeNode().childNodes.reduce(0) {
      $0 + ($1.geometry?.elements.first?.primitiveCount ?? 0)
    }
  }
}
