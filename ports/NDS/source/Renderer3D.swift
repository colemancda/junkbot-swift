import CNDS

/// Procedural low-poly 3D world rendering via libnds' fixed-function 3D GPU ("NitroGL",
/// `videoGL.h`) - replaces `Renderer.swift`'s sprite-blit drawing of bricks/entities (the backdrop
/// stays exactly as `Renderer.swift` already draws it - a software-composited bitmap on BG3; see
/// `main.swift`'s doc comment for why `MODE_5_3D` keeps that layer and adds a 3D one on top rather
/// than replacing it).
///
/// Reusing the actual baked LDraw geometry (`Models3D`, the macOS Metal/Android Vulkan renderers'
/// approach) is not possible on this hardware: `Models3D`'s JSON models total ~8-10MB against a
/// ~2.48MB ARM9 binary budget, and the DS's 3D GPU handles roughly 3000-4000 triangles/frame
/// (a single baked entity model can exceed that alone). Every brick/entity is instead a single
/// flat-colored box (`Geometry3D.drawUnitCube`, scaled/positioned per draw) - no studs, no LDraw
/// part shapes, no walk-cycle rig; a stand-in silhouette sized to the entity's existing sprite
/// footprint, not real part geometry.
///
/// All math is `Int32`/fixed-point (`f32` = 20.12, matching every other fixed-point calculation in
/// this port, e.g. `Renderer.swift`'s `blitBackdrop`) - the ARM946E-S has no FPU.
/// `inttof32`/etc (`nds/arm9/math.h`) are C function-like macros - Clang importer doesn't bridge
/// those into Swift at all (only simple object-like `#define` constants import), hence a local
/// equivalent: `f32` is 20.12 fixed-point, so converting a whole-number world-px value is just a
/// left shift by 12, matching the macro's own `(n) * (1 << 12)` definition exactly.
@inline(__always)
private func inttof32(_ n: Int32) -> Int32 { n << 12 }

/// `floattof32` for a compile-time constant, done by hand (the C macro is function-like, not
/// importable - see `inttof32` above): `f32` is 20.12, so multiply by 4096 and round.
@inline(__always)
private func f32(_ n: Double) -> Int32 { Int32((n * 4096).rounded()) }

enum Renderer3D {
  /// Half-depth (world px) every box is extruded along Z - flat "wafer" bricks/entities rather
  /// than fully length-cubed, matching `Metal3DSpace.depth`'s (30) scale on the other 3D ports
  /// without literally sharing code (that file is `simd`/float-based, unusable here).
  private static let halfDepth: Int32 = 15

  /// One-time GPU setup - call once before the main loop, after `videoSetMode(MODE_5_3D...)`.
  static func setup() {
    glInit()
    // Alpha 0: the 3D layer's own rear/clear plane is fully transparent, so `Renderer.swift`'s
    // BG3 bitmap backdrop shows through wherever no 3D geometry covers it - the two layers
    // composite automatically in hardware (`MODE_5_3D` = the same BG layout `MODE_5_2D` already
    // used, plus the 3D layer on BG0), no manual blending needed.
    glClearColor(0, 0, 0, 0)
    glClearDepth(fixed12d3(GL_MAX_DEPTH))
    glViewport(0, 0, UInt8(screenWidth - 1), UInt8(screenHeight - 1))

    // Orthographic, 1 world px = 1 GL unit, matching the 2D path's exact scroll math - `bottom`/
    // `top` swapped (192, 0) rather than (0, 192) so +Y stays screen-down, matching every other
    // world-space calculation in this codebase (the game's own 2D convention, not GL's usual
    // Y-up).
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrthof32(
      inttof32(0), inttof32(screenWidth), inttof32(screenHeight), inttof32(0),
      inttof32(-1000), inttof32(1000))

    // Oblique-projection shear - the ONE thing that gives this the same "3D-ish" look the macOS
    // Metal and web three.js renderers have: a straight orthographic camera (above) plus a z-based
    // shear that slides each box's far face sideways, so its top and one side become visible
    // instead of a flat head-on rectangle. Ported directly from `three-stuff/3d-main.js`'s
    // `obliqueProjection` GUI option (`alpha = PI/4`, `Szx = -0.5*cos(alpha)`, `Szy = -0.5*
    // sin(alpha)`), which `Metal3DManager.swift`'s `obliqueShear` already mirrors. Applied the same
    // way three.js does - `camera.projectionMatrix.multiply(shear)` - i.e. multiplied into the
    // projection matrix here (`glMultMatrix4x4` post-`glOrthof32` = ortho * shear). The DS `m4x4`
    // is column-major (verified against libnds' own `glOrthof32` register-feed order), the same
    // layout as Metal's `float4x4(columns:)`, so the shear's z-column carries the two shear terms.
    // `szy` sign is flipped from Metal's (`+`, not `-`) because this port keeps +Y screen-*down*
    // (the game's 2D convention) where Metal's scene space is +Y up - so the same on-screen tilt
    // needs the opposite y-coefficient.
    let szx = f32(-0.5 * 0.7071067811865476)  // -0.5 * cos(pi/4)
    let szy = f32(0.5 * 0.7071067811865476)  //  +0.5 * sin(pi/4), y-flipped (see above)
    let one = f32(1)
    // Column-major: col0, col1, (szx, szy, 1, 0) z-column, col3.
    let shearValues: [Int32] = [
      one, 0, 0, 0,
      0, one, 0, 0,
      szx, szy, one, 0,
      0, 0, 0, one,
    ]
    var shear = m4x4()
    withUnsafeMutablePointer(to: &shear.m) { tuplePtr in
      tuplePtr.withMemoryRebound(to: Int32.self, capacity: 16) { buf in
        for i in 0..<16 { buf[i] = shearValues[i] }
      }
    }
    glMultMatrix4x4(&shear)

    // Identity for BOTH the position and vector (normal) matrices - `GL_MODELVIEW` mode touches
    // both at once. Crucial for lighting: `drawBox` scales each box non-uniformly, but does so in
    // `GL_POSITION` mode (position matrix only), leaving THIS vector matrix at identity so
    // `Geometry3D`'s per-face normals reach the lighting engine undistorted (a non-uniform scale
    // applied to a normal would wreck the dot-product shading). Nothing here ever rotates, so the
    // vector matrix only ever needs to be identity.
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()

    // Hardware directional light, ported from the same source `Metal3DShaderSource`/`three-stuff/
    // 3d-main.js` use: `THREE.DirectionalLight` at `(-1000, 3200, 1500)` aimed at the origin. The
    // DS wants the direction light *travels* (origin - position), normalized, as a `v10` vector -
    // in this port's +Y-screen-down world that works out to roughly (0.27, 0.87, -0.41), i.e.
    // mostly straight down so up-facing tops are brightest, angled enough to also catch one side.
    // Set while the vector matrix is identity, so this stays a view-space direction.
    glLight(0, rgb15(0xFF, 0xFF, 0xFF), v10(139), v10(445), v10(-208))
    // No specular/emission (matches the other ports' pure-diffuse shading); zero the shininess
    // table so no stale specular leaks in. Ambient/diffuse are set per box in `drawBox`.
    glMaterialShinyness()
    glMaterialf(GL_SPECULAR, 0)
    glMaterialf(GL_EMISSION, 0)

    // `POLY_FORMAT_LIGHT0` enables light 0 for these polygons. `POLY_CULL_NONE`: `Geometry3D`'s
    // unit cube's face winding isn't guaranteed consistent per face, and rather than hand-verify
    // winding, cull nothing - every box is closed opaque geometry nothing sees the interior of.
    glPolyFmt(
      POLY_ALPHA(31) | UInt32(POLY_CULL_NONE.rawValue) | UInt32(POLY_FORMAT_LIGHT0.rawValue))
  }

  /// Draws every entity as a flat-colored box, camera-panned by `scrollX`/`scrollY` (the same
  /// values `Renderer.swift`'s 2D path already computes/clamps) - call once per frame, after the
  /// 2D backdrop pass has written into the bitmap back buffer.
  static func drawWorld(scrollX: Int32, scrollY: Int32) {
    // Everything positional goes through the POSITION matrix ONLY (not MODELVIEW, which would also
    // scale the vector/normal matrix) - see `setup`'s doc comment. The vector matrix stays the
    // identity `setup` left it at, keeping `Geometry3D`'s per-face normals correct under the
    // per-box non-uniform scale below.
    glMatrixMode(GL_POSITION)
    glLoadIdentity()
    glTranslatef32(inttof32(-scrollX), inttof32(-scrollY), 0)

    for e in gameEngine.entities {
      let (r, g, b) = color(for: e)
      let cx = e.x + e.width / 2
      let cy = e.y + e.height / 2
      let halfW = max(e.width / 2, 1)
      let halfH = max(e.height / 2, 1)
      drawBox(cx: cx, cy: cy, cz: 0, halfW: halfW, halfH: halfH, halfD: halfDepth, r: r, g: g, b: b)
    }

    glFlush(0)
  }

  private static func drawBox(
    cx: Int32, cy: Int32, cz: Int32, halfW: Int32, halfH: Int32, halfD: Int32, r: UInt8, g: UInt8,
    b: UInt8
  ) {
    // `glPushMatrix`/`glPopMatrix` push/pop both position and vector matrices together (one shared
    // hardware stack), but since the vector matrix is always identity here, saving/restoring it is
    // harmless - only the position matrix's translate+scale below actually matter.
    glPushMatrix()
    glTranslatef32(inttof32(cx), inttof32(cy), inttof32(cz))
    glScalef32(inttof32(halfW), inttof32(halfH), inttof32(halfD))
    // Diffuse (~half) + ambient (~half) split so a fully-lit face reads at ~full color and a
    // fully-shadowed face at ~half - the DS sums `ambient_material + diffuse_material * lightLevel`
    // per light, so this mirrors the ambient+directional balance the three.js/Metal renderers use
    // (strong ambient floor, no face goes black).
    glMaterialf(GL_DIFFUSE, scaledRGB15(r, g, b, num: 45, den: 100))
    glMaterialf(GL_AMBIENT, scaledRGB15(r, g, b, num: 55, den: 100))
    Geometry3D.drawUnitCube()
    glPopMatrix(1)
  }

  /// `RGB15(r>>3, g>>3, b>>3)` - the C macro is function-like (not importable); build the 5-bit
  /// packed color by hand.
  @inline(__always)
  private static func rgb15(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> UInt16 {
    UInt16(r >> 3) | (UInt16(g >> 3) << 5) | (UInt16(b >> 3) << 10)
  }

  /// `rgb15` with each 8-bit channel scaled by `num/den` first - for the dimmer diffuse/ambient
  /// material colors (see `drawBox`).
  @inline(__always)
  private static func scaledRGB15(_ r: UInt8, _ g: UInt8, _ b: UInt8, num: Int, den: Int) -> UInt16 {
    let sr = UInt16((Int(r) * num / den) >> 3)
    let sg = UInt16((Int(g) * num / den) >> 3)
    let sb = UInt16((Int(b) * num / den) >> 3)
    return sr | (sg << 5) | (sb << 10)
  }

  /// Flat stand-in colors, matching the palette every other 3D port's `brickColor`/entity-color
  /// tables already use (`Metal3DPalette.swift`, `Scene3DPalette.swift`) - kept as a local literal
  /// switch rather than shared code, since those files are `simd`/float-based (see this file's doc
  /// comment for why that's unusable on the DS).
  private static func color(for e: Entity) -> (UInt8, UInt8, UInt8) {
    switch e.type {
    case .brick:
      switch e.colorIndex {
      case 0: return (0xF4, 0xF4, 0xF4)  // white
      case 1: return (0xC4, 0x28, 0x1C)  // red
      case 2: return (0x2C, 0x8C, 0x3C)  // green
      case 3: return (0x1C, 0x54, 0xA8)  // blue
      case 4: return (0xF4, 0xC4, 0x14)  // yellow
      default: return (0x6C, 0x6C, 0x6C)  // gray immobile / fixed terrain
      }
    case .junkbot: return (0xE8, 0x7A, 0x1E)  // orange
    case .gearbot, .climbbot, .flybot, .eyebot: return (0x9A, 0x9A, 0x9A)  // gray enemies
    case .bin: return (0x3A, 0x8A, 0xC0)  // blue
    case .crate: return (0xC8, 0x96, 0x50)  // tan
    case .fire: return (0xE0, 0x40, 0x10)  // red-orange
    default: return (0x80, 0x80, 0x80)
    }
  }
}
