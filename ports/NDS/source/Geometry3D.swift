import CNDS

/// A single reusable "unit cube" (corners at +-1 in local `v16` space) - the DS's `v16` vertex
/// format is only 4 integer bits (`inttov16(n) = n << 12` overflows a 16-bit value for any `n`
/// outside roughly -8...+7), far too narrow to hold real world-pixel coordinates (bricks/entities
/// span up to ~900 world px). Rather than generate per-entity-sized vertex data (`Metal3DBrickGeometry.
/// swift`'s approach on Darwin/Android, where vertex coordinates are plain floats with no such
/// range limit), every brick/entity on the DS reuses this SAME tiny local geometry, scaled up to
/// its real half-extents via `glScalef32` (a 32-bit `f32` value, ample range) on the matrix stack -
/// see `Renderer3D.swift`'s `drawBox`. One shape, transformed per draw, matching NitroGL's own
/// immediate-mode-over-a-matrix-stack design instead of baking geometry per instance.
enum Geometry3D {
  /// `inttov16(1)` - one full unit in the local cube's own space.
  private static let n: Int16 = 1 << 12

  /// A packed `v10` unit normal component (`floattov10(1)` clamps to `0x1FF`, ~0.998 - the DS
  /// can't represent an exact 1.0 in 1.9 fixed point). `NORMAL_PACK` is a C function-like macro
  /// (not importable into Swift), so faces pack their own normals inline below.
  private static let u: Int32 = 0x1FF

  /// Packs three `v10` normal components (each in `-0x1FF...0x1FF`) into the 30-bit layout
  /// `glNormal` expects - the Swift equivalent of libnds' `NORMAL_PACK` macro.
  @inline(__always)
  private static func packNormal(_ x: Int32, _ y: Int32, _ z: Int32) -> UInt32 {
    (UInt32(bitPattern: x) & 0x3FF) | ((UInt32(bitPattern: y) & 0x3FF) << 10)
      | ((UInt32(bitPattern: z) & 0x3FF) << 20)
  }

  /// Emits the unit cube's 6 faces (2 triangles each) with a per-face normal, so the DS's hardware
  /// directional lighting (`Renderer3D.setup`) shades each face differently - top brightest, sides
  /// darker - giving the flat-colored boxes readable depth. Call between a `glMaterialf` diffuse/
  /// ambient setup and the matrix-stack transform that positions/sizes the box (see
  /// `Renderer3D.drawBox`).
  ///
  /// The normal must be sent through the DS's *vector* matrix, kept at identity by `Renderer3D`
  /// (the box's non-uniform `glScalef32` lives in the *position* matrix only, via `GL_POSITION`
  /// mode, so it never distorts these normals - see that file's doc comment). Since nothing here
  /// ever rotates, each face's world-axis normal is exactly what the lighting needs.
  static func drawUnitCube() {
    glBegin(GL_TRIANGLES)
    func v(_ x: Int16, _ y: Int16, _ z: Int16) { glVertex3v16(x, y, z) }

    // +z front
    glNormal(packNormal(0, 0, u))
    v(-n, -n, n); v(n, -n, n); v(n, n, n)
    v(-n, -n, n); v(n, n, n); v(-n, n, n)
    // -z back
    glNormal(packNormal(0, 0, -u))
    v(n, -n, -n); v(-n, -n, -n); v(-n, n, -n)
    v(n, -n, -n); v(-n, n, -n); v(n, n, -n)
    // +x right
    glNormal(packNormal(u, 0, 0))
    v(n, -n, n); v(n, -n, -n); v(n, n, -n)
    v(n, -n, n); v(n, n, -n); v(n, n, n)
    // -x left
    glNormal(packNormal(-u, 0, 0))
    v(-n, -n, -n); v(-n, -n, n); v(-n, n, n)
    v(-n, -n, -n); v(-n, n, n); v(-n, n, -n)
    // +y bottom (DS/world convention: +Y is screen-down, so this is the underside)
    glNormal(packNormal(0, u, 0))
    v(-n, n, n); v(n, n, n); v(n, n, -n)
    v(-n, n, n); v(n, n, -n); v(-n, n, -n)
    // -y top (the up-facing face - catches the most light)
    glNormal(packNormal(0, -u, 0))
    v(-n, -n, -n); v(n, -n, -n); v(n, -n, n)
    v(-n, -n, -n); v(n, -n, n); v(-n, -n, n)

    glEnd()
  }
}
