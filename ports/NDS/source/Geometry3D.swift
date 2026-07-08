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

  /// Emits the unit cube's 12 triangles (2 per face x 6 faces) via `glBegin`/`glVertex3v16`/
  /// `glEnd` - call between a `glColor3b` and the matrix-stack `glPushMatrix`/`glTranslatef32`/
  /// `glScalef32`/`glPopMatrix` sequence that positions and sizes it (see `Renderer3D.drawBox`).
  static func drawUnitCube() {
    glBegin(GL_TRIANGLES)
    func v(_ x: Int16, _ y: Int16, _ z: Int16) { glVertex3v16(x, y, z) }

    // +z front
    v(-n, -n, n); v(n, -n, n); v(n, n, n)
    v(-n, -n, n); v(n, n, n); v(-n, n, n)
    // -z back
    v(n, -n, -n); v(-n, -n, -n); v(-n, n, -n)
    v(n, -n, -n); v(-n, n, -n); v(n, n, -n)
    // +x right
    v(n, -n, n); v(n, -n, -n); v(n, n, -n)
    v(n, -n, n); v(n, n, -n); v(n, n, n)
    // -x left
    v(-n, -n, -n); v(-n, -n, n); v(-n, n, n)
    v(-n, -n, -n); v(-n, n, n); v(-n, n, -n)
    // +y bottom (DS/world convention: +Y is screen-down)
    v(-n, n, n); v(n, n, n); v(n, n, -n)
    v(-n, n, n); v(n, n, -n); v(-n, n, -n)
    // -y top
    v(-n, -n, -n); v(n, -n, -n); v(n, -n, n)
    v(-n, -n, -n); v(n, -n, n); v(-n, -n, n)

    glEnd()
  }
}
