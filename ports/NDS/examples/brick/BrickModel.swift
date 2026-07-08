import CNDS

/// One vertex of the hand-authored brick model: a `v16` (4.12 fixed) position and a `v10` (1.9
/// fixed) normal, the two formats the DS geometry engine consumes directly (`glVertex3v16`/
/// `glNormal`).
struct BrickVertex {
  var x: Int16
  var y: Int16
  var z: Int16
  var nx: Int16
  var ny: Int16
  var nz: Int16
}

/// A hand-authored, low-poly-but-recognisable LEGO 2x1 brick: a rectangular body ("outer hull")
/// plus four octagonal studs on top. This is the *baked-data* approach (a stored vertex table we
/// author and control the polygon count of), the middle ground between the plain procedural boxes
/// the NDS game renderer currently draws and the full ~8-10MB `Models3D` LDraw bakes the Metal/
/// Vulkan ports use (far too large/dense for the DS). Built once into a flat triangle list; a
/// standalone viewer (`main.swift`) renders it spinning so every face and stud is visible.
///
/// Dimensions are in "stud units" (1 unit = 1 stud), matching real LEGO proportions: a 2x1 brick
/// is 2 studs wide, 2 studs deep, 1.2 studs tall, with 2x2 studs (each ~0.6 studs across, ~0.18
/// tall) on top. +Y is up in this local space (a standalone viewer convention; the game renderer's
/// own +Y-down mapping is applied separately when this is wired in later).
enum BrickModel {
  private static func v16(_ d: Double) -> Int16 { Int16((d * 4096).rounded()) }
  private static func v10(_ d: Double) -> Int16 {
    Int16(Swift.max(-511, Swift.min(511, (d * 512).rounded())))
  }

  /// Every 3 entries form one triangle. Built once at startup.
  static let triangles: [BrickVertex] = build()

  /// Packs a `v10` normal into `glNormal`'s 30-bit layout (libnds' `NORMAL_PACK` is a
  /// function-like C macro, not importable into Swift).
  static func packNormal(_ x: Int16, _ y: Int16, _ z: Int16) -> UInt32 {
    (UInt32(bitPattern: Int32(x)) & 0x3FF) | ((UInt32(bitPattern: Int32(y)) & 0x3FF) << 10)
      | ((UInt32(bitPattern: Int32(z)) & 0x3FF) << 20)
  }

  private static func build() -> [BrickVertex] {
    var t: [BrickVertex] = []
    t.reserveCapacity(120 * 3)

    func vert(_ p: (Double, Double, Double), _ nrm: (Double, Double, Double)) -> BrickVertex {
      BrickVertex(
        x: v16(p.0), y: v16(p.1), z: v16(p.2), nx: v10(nrm.0), ny: v10(nrm.1), nz: v10(nrm.2))
    }
    func tri(
      _ a: (Double, Double, Double), _ b: (Double, Double, Double), _ c: (Double, Double, Double),
      _ nrm: (Double, Double, Double)
    ) {
      t.append(vert(a, nrm))
      t.append(vert(b, nrm))
      t.append(vert(c, nrm))
    }
    func quad(
      _ a: (Double, Double, Double), _ b: (Double, Double, Double), _ c: (Double, Double, Double),
      _ d: (Double, Double, Double), _ nrm: (Double, Double, Double)
    ) {
      tri(a, b, c, nrm)
      tri(a, c, d, nrm)
    }

    // ---- Body ("outer hull"): a 2 (wide) x 1.2 (tall) x 2 (deep) box, centered on x/z. ----
    let hw = 1.0  // half width (2 studs)
    let hd = 1.0  // half depth (2 studs)
    let top = 0.6  // +y top face (1.2 tall total)
    let bot = -0.6

    // +z front
    quad((-hw, bot, hd), (hw, bot, hd), (hw, top, hd), (-hw, top, hd), (0, 0, 1))
    // -z back
    quad((hw, bot, -hd), (-hw, bot, -hd), (-hw, top, -hd), (hw, top, -hd), (0, 0, -1))
    // +x right
    quad((hw, bot, hd), (hw, bot, -hd), (hw, top, -hd), (hw, top, hd), (1, 0, 0))
    // -x left
    quad((-hw, bot, -hd), (-hw, bot, hd), (-hw, top, hd), (-hw, top, -hd), (-1, 0, 0))
    // +y top (studs sit on this)
    quad((-hw, top, hd), (hw, top, hd), (hw, top, -hd), (-hw, top, -hd), (0, 1, 0))
    // -y bottom
    quad((-hw, bot, -hd), (hw, bot, -hd), (hw, bot, hd), (-hw, bot, hd), (0, -1, 0))

    // ---- Studs: 2x2 grid of octagonal cylinders on top. ----
    // Unit octagon direction vectors (cos, sin at 45deg steps) - hardcoded so no runtime trig.
    let c = 0.7071067811865476
    let oct: [(Double, Double)] = [
      (1, 0), (c, c), (0, 1), (-c, c), (-1, 0), (-c, -c), (0, -1), (c, -c),
    ]
    let studR = 0.3
    let studBase = top
    let studTop = top + 0.18
    for sx in [-0.5, 0.5] {
      for sz in [-0.5, 0.5] {
        for i in 0..<8 {
          let (dx0, dz0) = oct[i]
          let (dx1, dz1) = oct[(i + 1) % 8]
          let p0b = (sx + dx0 * studR, studBase, sz + dz0 * studR)
          let p1b = (sx + dx1 * studR, studBase, sz + dz1 * studR)
          let p0t = (sx + dx0 * studR, studTop, sz + dz0 * studR)
          let p1t = (sx + dx1 * studR, studTop, sz + dz1 * studR)
          // Side face - radial normal (average of the two edge directions; v10's clamp handles
          // the slight non-unit length).
          let sideN = ((dx0 + dx1) * 0.5, 0.0, (dz0 + dz1) * 0.5)
          quad(p0b, p1b, p1t, p0t, sideN)
          // Top cap wedge - fan from the stud's center, facing up.
          tri((sx, studTop, sz), p0t, p1t, (0, 1, 0))
        }
      }
    }

    return t
  }

  /// Emits the whole brick via the DS geometry engine - one `glNormal` per triangle (all 3 of a
  /// triangle's stored vertices share the face normal). Call inside a `glBegin(GL_TRIANGLES)` /
  /// `glEnd()` pair after setting the material colors.
  static func draw() {
    glBegin(GL_TRIANGLES)
    let verts = triangles
    var i = 0
    while i < verts.count {
      let a = verts[i]
      glNormal(packNormal(a.nx, a.ny, a.nz))
      glVertex3v16(a.x, a.y, a.z)
      let b = verts[i + 1]
      glVertex3v16(b.x, b.y, b.z)
      let cc = verts[i + 2]
      glVertex3v16(cc.x, cc.y, cc.z)
      i += 3
    }
    glEnd()
  }
}
