import CNDS

/// Low-poly 3D world rendering via libnds' fixed-function 3D GPU ("NitroGL", `videoGL.h`) -
/// replaces `Renderer.swift`'s sprite-blit drawing of bricks/entities (the backdrop stays a
/// software-composited bitmap on BG3; see `main.swift` for why `MODE_5_3D` keeps that layer and
/// adds a 3D one on top).
///
/// Each entity draws a hand-authored low-poly model (`Models`/`Mesh`) - real, recognisable shapes
/// (studded bricks, a boxy Junkbot, a round bin, ...) whose polygon counts we control, not the
/// ~8-10MB `Models3D` LDraw bakes the Metal/Vulkan ports use (far too large/dense for this
/// hardware - ~2.48MB ARM9 budget, ~2048 polys/frame). Models are authored +Y-up in stud units;
/// `Mesh.unitModelForGame` remaps each into a [-1,1] X/Y "unit model" (+Y flipped to the game's
/// screen-down convention) so the same `translate(center) + scale(halfW,halfH,halfDepth)` transform
/// the old plain boxes used stretches it to fill the entity's sprite footprint.
///
/// All math is `Int32`/fixed-point (`f32` = 20.12, matching every other fixed-point calculation in
/// this port) - the ARM946E-S has no FPU. `inttof32`/etc are C function-like macros the Clang
/// importer can't bridge, so they're reimplemented here (`f32` = 20.12: multiply by 4096).
@inline(__always)
private func inttof32(_ n: Int32) -> Int32 { n << 12 }
@inline(__always)
private func f32(_ n: Double) -> Int32 { Int32((n * 4096).rounded()) }
@inline(__always)
private func rgb15(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> UInt16 {
  UInt16(r >> 3) | (UInt16(g >> 3) << 5) | (UInt16(b >> 3) << 10)
}

/// One cached game-ready ("unit") model, keyed for a linear-scan lookup (a plain array rather than
/// a `Dictionary`, which has misbehaved under Embedded Swift elsewhere in this project).
private struct CachedModel {
  var key: Int32
  var mesh: Mesh
}
/// Non-brick entity models, keyed by `EntityType.rawValue`. Built once, on first sight of a type.
private var entityModels: [CachedModel] = []
/// Brick models, keyed by `widthInStuds * 16 + colorIndex` (bricks vary in width and color).
private var brickModels: [CachedModel] = []

enum Renderer3D {
  /// Half-depth (world px) every model is extruded along Z - a model's Z is left in stud units by
  /// `unitModelForGame`, so this scale (1 stud = 15px = `CELL_W`) reproduces true depth.
  private static let halfDepth: Int32 = 15

  /// One-time GPU setup - call once before the main loop, after `videoSetMode(MODE_5_3D...)`.
  static func setup() {
    glInit()
    // Alpha 0: the 3D layer's rear/clear plane is fully transparent, so `Renderer.swift`'s BG3
    // bitmap backdrop shows through wherever no 3D geometry covers it - the two layers composite
    // automatically in hardware (`MODE_5_3D`), no manual blending needed.
    glClearColor(0, 0, 0, 0)
    glClearDepth(fixed12d3(GL_MAX_DEPTH))
    glViewport(0, 0, UInt8(screenWidth - 1), UInt8(screenHeight - 1))

    // Orthographic, 1 world px = 1 GL unit, matching the 2D path's exact scroll math. `bottom`/
    // `top` are swapped (192, 0) so +Y stays screen-down (the game's 2D convention).
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrthof32(
      inttof32(0), inttof32(screenWidth), inttof32(screenHeight), inttof32(0),
      inttof32(-1000), inttof32(1000))

    // Oblique-projection shear - the "3D-ish" look the macOS Metal and web three.js renderers have:
    // a straight orthographic camera plus a z-based shear sliding each model's far face sideways so
    // its top and one side show. Ported from `three-stuff/3d-main.js`'s `obliqueProjection` GUI
    // option (`alpha = PI/4`, `Szx = -0.5*cos`, `Szy = -0.5*sin`), which `Metal3DManager`'s
    // `obliqueShear` also mirrors. Multiplied into the projection matrix (post-`glOrthof32` =
    // ortho * shear), the same way three.js does. The DS `m4x4` is column-major (verified against
    // libnds' own `glOrthof32` register order); `szy`'s sign is flipped from Metal's because this
    // port keeps +Y screen-down.
    let szx = f32(-0.5 * 0.7071067811865476)
    let szy = f32(0.5 * 0.7071067811865476)
    let one = f32(1)
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

    // Identity for BOTH the position and vector (normal) matrices (`GL_MODELVIEW` touches both).
    // Crucial for lighting: `drawEntity` scales each model non-uniformly, but in `GL_POSITION` mode
    // (position matrix only), leaving THIS vector matrix at identity so model normals reach the
    // lighting engine undistorted. Nothing here rotates, so the vector matrix stays identity.
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()

    // Hardware directional light, ported from the same `THREE.DirectionalLight` at (-1000, 3200,
    // 1500) aimed at the origin - direction light travels, normalized, ~(0.27, 0.87, -0.41) in
    // this +Y-down world (mostly down, so tops are brightest). Set while the vector matrix is
    // identity so it stays a view-space direction.
    glLight(0, rgb15(0xFF, 0xFF, 0xFF), v10(139), v10(445), v10(-208))
    glMaterialShinyness()
    glMaterialf(GL_SPECULAR, 0)
    glMaterialf(GL_EMISSION, 0)

    // `POLY_FORMAT_LIGHT0` enables light 0. `POLY_CULL_NONE`: the models' face winding isn't
    // guaranteed consistent, and they're closed opaque geometry nothing sees the interior of.
    glPolyFmt(
      POLY_ALPHA(31) | UInt32(POLY_CULL_NONE.rawValue) | UInt32(POLY_FORMAT_LIGHT0.rawValue))
  }

  /// Draws every entity's model, camera-panned by `scrollX`/`scrollY` (the same values
  /// `Renderer.swift`'s 2D path computes/clamps) - call once per frame.
  static func drawWorld(scrollX: Int32, scrollY: Int32) {
    // Everything positional goes through the POSITION matrix ONLY (not MODELVIEW, which would also
    // scale the vector/normal matrix) - see `setup`. The vector matrix stays identity, keeping the
    // models' normals correct under the per-entity non-uniform footprint scale below.
    glMatrixMode(GL_POSITION)
    glLoadIdentity()
    glTranslatef32(inttof32(-scrollX), inttof32(-scrollY), 0)

    for e in gameEngine.entities {
      if e.type == .brick {
        drawEntity(brickMesh(width: e.widthInStuds, color: e.colorIndex), e)
      } else if let mesh = entityMesh(e.type) {
        drawEntity(mesh, e)
      }
    }

    glFlush(0)
  }

  private static func drawEntity(_ mesh: Mesh, _ e: Entity) {
    let cx = e.x + e.width / 2
    let cy = e.y + e.height / 2
    let halfW = max(e.width / 2, 1)
    let halfH = max(e.height / 2, 1)
    // Mirror left/right facing by negating the X scale (harmless for symmetric models; correct for
    // any asymmetric ones). Done in the POSITION matrix so normals are unaffected.
    let signW = e.facing == -1 ? -halfW : halfW
    glPushMatrix()
    glTranslatef32(inttof32(cx), inttof32(cy), 0)
    glScalef32(inttof32(signW), inttof32(halfH), inttof32(halfDepth))
    mesh.draw()
    glPopMatrix(1)
  }

  // MARK: - Model cache

  private static func brickMesh(width: Int32, color: Int32) -> Mesh {
    let key = width * 16 + color
    for c in brickModels where c.key == key { return c.mesh }
    // Only the player-draggable colored bricks (colorIndex 0-4) get studs; immobile gray terrain
    // (the numerous, wide bricks) stays a plain box to fit the DS polygon budget - see
    // `Models.brick`. Bake with the body (authored half-height 0.6 stud units) as the Y reference
    // so the body fills its 18px row and the studs protrude up to interlock with the brick above.
    let studded = color >= 0 && color <= 4
    let m = Models.brick(widthStuds: Int(width), colorIndex: Int(color), studded: studded)
      .unitModelForGame(bodyCenterYV16: 0, bodyHalfYV16: 0.6 * 4096)
    brickModels.append(CachedModel(key: key, mesh: m))
    return m
  }

  private static func entityMesh(_ t: EntityType) -> Mesh? {
    let key = Int32(t.rawValue)
    for c in entityModels where c.key == key { return c.mesh }
    guard let built = buildEntityMesh(t) else { return nil }
    let m = built.unitModelForGame()
    entityModels.append(CachedModel(key: key, mesh: m))
    return m
  }

  private static func buildEntityMesh(_ t: EntityType) -> Mesh? {
    switch t {
    case .junkbot: return Models.junkbot()
    case .gearbot: return Models.gearbot()
    case .climbbot: return Models.climbbot()
    case .flybot: return Models.flybot()
    case .eyebot: return Models.eyebot()
    case .bin: return Models.bin()
    case .crate: return Models.crate()
    case .fire: return Models.fire()
    case .fan: return Models.fan()
    case .`switch`: return Models.switchModel()
    case .pipe: return Models.pipe()
    case .shield: return Models.shield()
    case .teleport: return Models.teleport()
    case .laser: return Models.laser()
    case .jump: return Models.jump()
    default: return nil  // droplet / levelBounds / unknown - not drawn in 3D
    }
  }
}
