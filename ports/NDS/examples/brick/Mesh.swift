import CNDS

/// One vertex: a `v16` (4.12 fixed) position and a `v10` (1.9 fixed) normal - the two formats the
/// DS geometry engine consumes directly (`glVertex3v16`/`glNormal`).
struct MeshVertex {
  var x: Int16
  var y: Int16
  var z: Int16
  var nx: Int16
  var ny: Int16
  var nz: Int16
}

/// A run of triangles sharing one flat color - drawn as a single `glMaterialf`+`glBegin` group.
struct MeshPart {
  var r: Int
  var g: Int
  var b: Int
  var tris: [MeshVertex]
}

/// A tiny hand-authored-geometry builder: accumulates flat-colored triangles from a handful of
/// primitives (box, octagonal stud/cylinder/disc, cone), merging same-color geometry so each
/// distinct color becomes one draw call. This is the *baked-data* middle ground between the NDS
/// game renderer's plain procedural boxes and the ~8-10MB `Models3D` LDraw bakes the Metal/Vulkan
/// ports use (far too large/dense for the DS) - real, recognisable shapes whose polygon count we
/// control. All coordinates are in "stud units" (1 unit = 1 LEGO stud), +Y up.
struct Mesh {
  var parts: [MeshPart] = []

  // MARK: - Fixed-point conversion

  static func v16(_ d: Double) -> Int16 { Int16((d * 4096).rounded()) }
  static func v10(_ d: Double) -> Int16 {
    Int16(Swift.max(-511, Swift.min(511, (d * 512).rounded())))
  }
  /// Packs a `v10` normal into `glNormal`'s 30-bit layout (libnds' `NORMAL_PACK` is a
  /// function-like C macro, not importable into Swift).
  static func packNormal(_ x: Int16, _ y: Int16, _ z: Int16) -> UInt32 {
    (UInt32(bitPattern: Int32(x)) & 0x3FF) | ((UInt32(bitPattern: Int32(y)) & 0x3FF) << 10)
      | ((UInt32(bitPattern: Int32(z)) & 0x3FF) << 20)
  }

  private static let c = 0.7071067811865476
  /// Unit octagon direction vectors (cos, sin at 45deg steps) - hardcoded so no runtime trig.
  static let octagon: [(Double, Double)] = [
    (1, 0), (c, c), (0, 1), (-c, c), (-1, 0), (-c, -c), (0, -1), (c, -c),
  ]

  // MARK: - Emit

  private mutating func emit(_ r: Int, _ g: Int, _ b: Int, _ verts: [MeshVertex]) {
    for i in parts.indices where parts[i].r == r && parts[i].g == g && parts[i].b == b {
      parts[i].tris.append(contentsOf: verts)
      return
    }
    parts.append(MeshPart(r: r, g: g, b: b, tris: verts))
  }

  private func vert(_ p: (Double, Double, Double), _ nrm: (Double, Double, Double)) -> MeshVertex {
    MeshVertex(
      x: Self.v16(p.0), y: Self.v16(p.1), z: Self.v16(p.2), nx: Self.v10(nrm.0), ny: Self.v10(nrm.1),
      nz: Self.v10(nrm.2))
  }

  // MARK: - Primitives

  /// An axis-aligned box centered at (cx,cy,cz) with the given half-extents.
  mutating func box(
    _ cx: Double, _ cy: Double, _ cz: Double, _ hx: Double, _ hy: Double, _ hz: Double,
    _ r: Int, _ g: Int, _ b: Int
  ) {
    let x0 = cx - hx, x1 = cx + hx, y0 = cy - hy, y1 = cy + hy, z0 = cz - hz, z1 = cz + hz
    func face(
      _ a: (Double, Double, Double), _ bb: (Double, Double, Double), _ cc: (Double, Double, Double),
      _ d: (Double, Double, Double), _ n: (Double, Double, Double)
    ) {
      emit(r, g, b, [vert(a, n), vert(bb, n), vert(cc, n), vert(a, n), vert(cc, n), vert(d, n)])
    }
    face((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (0, 0, 1))  // +z
    face((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (0, 0, -1))  // -z
    face((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (1, 0, 0))  // +x
    face((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0), (-1, 0, 0))  // -x
    face((x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0), (0, 1, 0))  // +y top
    face((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), (0, -1, 0))  // -y bottom
  }

  /// A vertical octagonal cylinder (its axis along Y), with top and bottom caps.
  mutating func cylinderY(
    _ cx: Double, _ cy: Double, _ cz: Double, _ radius: Double, _ halfH: Double,
    _ r: Int, _ g: Int, _ b: Int
  ) {
    let y0 = cy - halfH, y1 = cy + halfH
    for i in 0..<8 {
      let (dx0, dz0) = Self.octagon[i]
      let (dx1, dz1) = Self.octagon[(i + 1) % 8]
      let p0 = (cx + dx0 * radius, cz + dz0 * radius)
      let p1 = (cx + dx1 * radius, cz + dz1 * radius)
      let sideN = ((dx0 + dx1) * 0.5, 0.0, (dz0 + dz1) * 0.5)
      emit(
        r, g, b,
        [
          vert((p0.0, y0, p0.1), sideN), vert((p1.0, y0, p1.1), sideN),
          vert((p1.0, y1, p1.1), sideN),
          vert((p0.0, y0, p0.1), sideN), vert((p1.0, y1, p1.1), sideN),
          vert((p0.0, y1, p0.1), sideN),
        ])
      emit(
        r, g, b,
        [  // top + bottom cap wedges
          vert((cx, y1, cz), (0, 1, 0)), vert((p0.0, y1, p0.1), (0, 1, 0)),
          vert((p1.0, y1, p1.1), (0, 1, 0)),
          vert((cx, y0, cz), (0, -1, 0)), vert((p1.0, y0, p1.1), (0, -1, 0)),
          vert((p0.0, y0, p0.1), (0, -1, 0)),
        ])
    }
  }

  /// A horizontal octagonal cylinder (its axis along X), with end caps - for pipes.
  mutating func cylinderX(
    _ cx: Double, _ cy: Double, _ cz: Double, _ radius: Double, _ halfL: Double,
    _ r: Int, _ g: Int, _ b: Int
  ) {
    let x0 = cx - halfL, x1 = cx + halfL
    for i in 0..<8 {
      let (dy0, dz0) = Self.octagon[i]
      let (dy1, dz1) = Self.octagon[(i + 1) % 8]
      let p0 = (cy + dy0 * radius, cz + dz0 * radius)
      let p1 = (cy + dy1 * radius, cz + dz1 * radius)
      let sideN = (0.0, (dy0 + dy1) * 0.5, (dz0 + dz1) * 0.5)
      emit(
        r, g, b,
        [
          vert((x0, p0.0, p0.1), sideN), vert((x1, p0.0, p0.1), sideN),
          vert((x1, p1.0, p1.1), sideN),
          vert((x0, p0.0, p0.1), sideN), vert((x1, p1.0, p1.1), sideN),
          vert((x0, p1.0, p1.1), sideN),
        ])
      emit(
        r, g, b,
        [
          vert((x1, cy, cz), (1, 0, 0)), vert((x1, p0.0, p0.1), (1, 0, 0)),
          vert((x1, p1.0, p1.1), (1, 0, 0)),
          vert((x0, cy, cz), (-1, 0, 0)), vert((x0, p1.0, p1.1), (-1, 0, 0)),
          vert((x0, p0.0, p0.1), (-1, 0, 0)),
        ])
    }
  }

  /// A flat octagonal disc facing +Z (a thin coin) - for gearbot gears, eyebot eyes, teleport pads.
  mutating func discZ(
    _ cx: Double, _ cy: Double, _ cz: Double, _ radius: Double, _ r: Int, _ g: Int, _ b: Int
  ) {
    for i in 0..<8 {
      let (dx0, dy0) = Self.octagon[i]
      let (dx1, dy1) = Self.octagon[(i + 1) % 8]
      emit(
        r, g, b,
        [
          vert((cx, cy, cz), (0, 0, 1)),
          vert((cx + dx0 * radius, cy + dy0 * radius, cz), (0, 0, 1)),
          vert((cx + dx1 * radius, cy + dy1 * radius, cz), (0, 0, 1)),
        ])
    }
  }

  /// An octagonal cone (base ring up to a single apex) - for flames.
  mutating func cone(
    _ cx: Double, _ baseY: Double, _ cz: Double, _ radius: Double, _ height: Double,
    _ r: Int, _ g: Int, _ b: Int
  ) {
    let apex = (cx, baseY + height, cz)
    for i in 0..<8 {
      let (dx0, dz0) = Self.octagon[i]
      let (dx1, dz1) = Self.octagon[(i + 1) % 8]
      let p0 = (cx + dx0 * radius, baseY, cz + dz0 * radius)
      let p1 = (cx + dx1 * radius, baseY, cz + dz1 * radius)
      // Approximate side normal: radial, tilted up toward the apex.
      let n = ((dx0 + dx1) * 0.4, 0.6, (dz0 + dz1) * 0.4)
      emit(r, g, b, [vert(p0, n), vert(p1, n), vert(apex, n)])
    }
  }

  // MARK: - Draw

  /// Renders every part - one `glMaterialf` diffuse/ambient split per color (lit face ~full color,
  /// shadowed face ~half, never black), then the triangles. Call after the modelview transform is
  /// set; a directional light + `POLY_FORMAT_LIGHT0` must already be active (see `main.swift`).
  func draw() {
    for part in parts {
      glMaterialf(GL_DIFFUSE, Self.material5(part.r, part.g, part.b, num: 48, den: 100))
      glMaterialf(GL_AMBIENT, Self.material5(part.r, part.g, part.b, num: 55, den: 100))
      glBegin(GL_TRIANGLES)
      let t = part.tris
      var i = 0
      while i < t.count {
        let a = t[i]
        glNormal(Self.packNormal(a.nx, a.ny, a.nz))
        glVertex3v16(a.x, a.y, a.z)
        let b = t[i + 1]
        glVertex3v16(b.x, b.y, b.z)
        let cc = t[i + 2]
        glVertex3v16(cc.x, cc.y, cc.z)
        i += 3
      }
      glEnd()
    }
  }

  /// `RGB15(r,g,b)` with each 8-bit channel scaled by `num/den` then dropped to 5-bit - the C
  /// `RGB15` macro is function-like (not importable).
  static func material5(_ r: Int, _ g: Int, _ b: Int, num: Int, den: Int) -> UInt16 {
    let r5 = UInt16((r * num / den) >> 3)
    let g5 = UInt16((g * num / den) >> 3)
    let b5 = UInt16((b * num / den) >> 3)
    return r5 | (g5 << 5) | (b5 << 10)
  }
}
