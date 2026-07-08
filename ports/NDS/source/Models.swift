/// Hand-authored low-poly stand-ins for every Junkbot entity type, built from `Mesh` primitives.
/// Each is a recognisable silhouette (real shapes with the right colors and proportions), not the
/// full `Models3D` LDraw geometry - see `Mesh.swift`'s doc comment for why the DS needs this
/// middle ground. Coordinates are "stud units", +Y up, roughly centered on the origin so the
/// viewer (`main.swift`) can frame and spin them uniformly.
struct Model {
  var name: StaticString
  var mesh: Mesh

  var triangleCount: Int { mesh.parts.reduce(0) { $0 + $1.tris.count / 3 } }
  var partCount: Int { mesh.parts.count }
}

enum Models {
  // Shared palette (8-bit RGB), matching the other ports' entity colors where they exist.
  private static let red = (0xC4, 0x28, 0x1C)
  private static let orange = (0xE8, 0x7A, 0x1E)
  private static let yellow = (0xF4, 0xC4, 0x14)
  private static let green = (0x2C, 0x8C, 0x3C)
  private static let blue = (0x3A, 0x8A, 0xC0)
  private static let gray = (0x9A, 0x9A, 0x9A)
  private static let darkGray = (0x54, 0x54, 0x54)
  private static let tan = (0xC8, 0x96, 0x50)
  private static let brown = (0x7A, 0x50, 0x28)
  private static let white = (0xF0, 0xF0, 0xF0)
  private static let dark = (0x22, 0x22, 0x22)
  private static let cyan = (0x40, 0xC0, 0xD0)
  private static let purple = (0x9A, 0x50, 0xC0)

  static let all: [Model] = [
    Model(name: "2x1 Brick", mesh: brick2x1()),
    Model(name: "Junkbot", mesh: junkbot()),
    Model(name: "Gearbot", mesh: gearbot()),
    Model(name: "Climbbot", mesh: climbbot()),
    Model(name: "Flybot", mesh: flybot()),
    Model(name: "Eyebot", mesh: eyebot()),
    Model(name: "Bin", mesh: bin()),
    Model(name: "Crate", mesh: crate()),
    Model(name: "Fire", mesh: fire()),
    Model(name: "Fan", mesh: fan()),
    Model(name: "Switch", mesh: switchModel()),
    Model(name: "Pipe", mesh: pipe()),
    Model(name: "Shield", mesh: shield()),
    Model(name: "Teleport", mesh: teleport()),
    Model(name: "Laser", mesh: laser()),
    Model(name: "Jump", mesh: jump()),
  ]

  // MARK: - Bricks

  static func brick2x1() -> Mesh { brick(widthStuds: 2, colorIndex: 1, studded: true) }

  /// The game's brick color palette (matches `Renderer3D`'s old `color(for:)` and the other 3D
  /// ports' `brickColor`).
  static func brickColor(_ colorIndex: Int) -> (Int, Int, Int) {
    switch colorIndex {
    case 0: return (0xF4, 0xF4, 0xF4)  // white
    case 1: return (0xC4, 0x28, 0x1C)  // red
    case 2: return (0x2C, 0x8C, 0x3C)  // green
    case 3: return (0x1C, 0x54, 0xA8)  // blue
    case 4: return (0xF4, 0xC4, 0x14)  // yellow
    default: return (0x6C, 0x6C, 0x6C)  // gray immobile / fixed terrain
    }
  }

  /// A parametric LEGO brick: a body box, optionally topped with a 2-deep x `widthStuds`-wide grid
  /// of studs (`Mesh.stud`, 16 tris each, no hidden bottom cap). `studded` is off for immobile gray
  /// terrain - those bricks are numerous and wide, and studding them all would blow the DS's
  /// ~2048-poly/frame budget (dropping everything drawn afterward); the player-draggable colored
  /// bricks (few, small) keep their studs. The body is authored 1.2 units tall = one 18px game row;
  /// `Renderer3D` bakes with the *body* as the Y reference so studs protrude up and interlock with
  /// the brick stacked above.
  static func brick(widthStuds: Int, colorIndex: Int, studded: Bool) -> Mesh {
    let w = Swift.max(1, widthStuds)
    let (r, g, b) = brickColor(colorIndex)
    var m = Mesh()
    let hw = Double(w) / 2  // half width in stud units
    m.box(0, 0, 0, hw, 0.6, 1.0, r, g, b)  // body (2 studs deep)
    if studded {
      for col in 0..<w {
        let sx = Double(col) + 0.5 - hw  // stud column centers
        for sz in [-0.5, 0.5] {  // 2 rows deep
          m.stud(sx, sz, 0.6, 0.28, 0.16, r, g, b)
        }
      }
    }
    return m
  }

  // MARK: - Characters

  static func junkbot() -> Mesh {
    var m = Mesh()
    m.box(0, 0, 0, 0.9, 0.7, 0.7, orange.0, orange.1, orange.2)  // torso
    m.box(0, 0.85, 0, 0.7, 0.15, 0.6, yellow.0, yellow.1, yellow.2)  // lid
    m.box(-0.35, 0.15, 0.72, 0.12, 0.1, 0.05, dark.0, dark.1, dark.2)  // eyes
    m.box(0.35, 0.15, 0.72, 0.12, 0.1, 0.05, dark.0, dark.1, dark.2)
    m.discZ(0, -0.25, 0.72, 0.28, darkGray.0, darkGray.1, darkGray.2)  // recycle badge
    m.box(0, -1.1, 0, 0.3, 0.4, 0.3, gray.0, gray.1, gray.2)  // leg
    m.box(0, -1.55, 0.1, 0.5, 0.1, 0.4, gray.0, gray.1, gray.2)  // foot
    return m
  }

  static func gearbot() -> Mesh {
    var m = Mesh()
    m.box(0, 0, 0, 0.8, 0.6, 0.6, gray.0, gray.1, gray.2)  // body
    m.discZ(0, 0, 0.62, 0.5, darkGray.0, darkGray.1, darkGray.2)  // gear rim
    m.discZ(0, 0, 0.64, 0.26, red.0, red.1, red.2)  // gear hub
    m.box(-0.3, 0.35, 0.55, 0.12, 0.1, 0.05, dark.0, dark.1, dark.2)  // eyes
    m.box(0.3, 0.35, 0.55, 0.12, 0.1, 0.05, dark.0, dark.1, dark.2)
    return m
  }

  static func climbbot() -> Mesh {
    var m = Mesh()
    m.box(0, 0, 0, 0.7, 0.7, 0.6, gray.0, gray.1, gray.2)  // body
    m.box(-0.9, 0, 0, 0.2, 0.5, 0.45, green.0, green.1, green.2)  // claws
    m.box(0.9, 0, 0, 0.2, 0.5, 0.45, green.0, green.1, green.2)
    m.box(-0.3, 0.35, 0.62, 0.12, 0.1, 0.05, dark.0, dark.1, dark.2)  // eyes
    m.box(0.3, 0.35, 0.62, 0.12, 0.1, 0.05, dark.0, dark.1, dark.2)
    return m
  }

  static func flybot() -> Mesh {
    var m = Mesh()
    m.box(0, 0, 0, 0.5, 0.4, 0.6, gray.0, gray.1, gray.2)  // body
    m.box(-0.95, 0.1, 0, 0.5, 0.05, 0.5, darkGray.0, darkGray.1, darkGray.2)  // wings
    m.box(0.95, 0.1, 0, 0.5, 0.05, 0.5, darkGray.0, darkGray.1, darkGray.2)
    m.box(0, -0.05, 0.65, 0.16, 0.16, 0.1, red.0, red.1, red.2)  // nose
    return m
  }

  static func eyebot() -> Mesh {
    var m = Mesh()
    m.box(0, 0, 0, 0.6, 0.6, 0.5, gray.0, gray.1, gray.2)  // body
    m.discZ(0, 0, 0.55, 0.42, white.0, white.1, white.2)  // eye white
    m.discZ(0, 0, 0.58, 0.18, dark.0, dark.1, dark.2)  // pupil
    return m
  }

  // MARK: - Objects / hazards

  static func bin() -> Mesh {
    var m = Mesh()
    m.cylinderY(0, 0, 0, 0.65, 0.8, blue.0, blue.1, blue.2)  // body
    m.cylinderY(0, 0.82, 0, 0.72, 0.06, darkGray.0, darkGray.1, darkGray.2)  // rim
    m.cylinderY(0, 0.92, 0, 0.68, 0.05, gray.0, gray.1, gray.2)  // lid
    m.discZ(0, 0.1, 0.66, 0.32, white.0, white.1, white.2)  // recycle badge
    return m
  }

  static func crate() -> Mesh {
    var m = Mesh()
    m.box(0, 0, 0, 0.9, 0.9, 0.9, tan.0, tan.1, tan.2)  // body
    for sx in [-0.85, 0.85] {
      for sz in [-0.85, 0.85] {
        m.box(sx, 0, sz, 0.1, 0.9, 0.1, brown.0, brown.1, brown.2)  // corner posts
      }
    }
    m.box(0, 0.9, 0, 0.95, 0.06, 0.95, brown.0, brown.1, brown.2)  // top rim
    m.box(0, -0.9, 0, 0.95, 0.06, 0.95, brown.0, brown.1, brown.2)  // bottom rim
    return m
  }

  static func fire() -> Mesh {
    var m = Mesh()
    m.box(0, -0.75, 0, 0.9, 0.1, 0.5, darkGray.0, darkGray.1, darkGray.2)  // base
    m.cone(-0.45, -0.65, 0, 0.3, 0.8, 0xE0, 0x40, 0x10)  // outer flames
    m.cone(0.0, -0.65, 0, 0.35, 1.15, 0xE0, 0x40, 0x10)
    m.cone(0.45, -0.65, 0, 0.3, 0.85, 0xE0, 0x40, 0x10)
    m.cone(0.0, -0.5, 0.05, 0.2, 0.75, 0xF4, 0x94, 0x14)  // inner flame
    return m
  }

  static func fan() -> Mesh {
    var m = Mesh()
    m.box(0, -0.7, 0, 0.8, 0.15, 0.6, gray.0, gray.1, gray.2)  // base
    m.box(0, 0, 0.12, 0.75, 0.14, 0.04, darkGray.0, darkGray.1, darkGray.2)  // blade
    m.box(0, 0, 0.12, 0.14, 0.75, 0.04, darkGray.0, darkGray.1, darkGray.2)  // blade
    m.discZ(0, 0, 0.16, 0.16, gray.0, gray.1, gray.2)  // hub
    return m
  }

  static func switchModel() -> Mesh {
    var m = Mesh()
    m.box(0, -0.5, 0, 0.5, 0.25, 0.5, gray.0, gray.1, gray.2)  // base
    m.box(0.18, 0.1, 0, 0.09, 0.55, 0.09, red.0, red.1, red.2)  // lever
    m.cylinderY(0.18, 0.45, 0, 0.14, 0.1, red.0, red.1, red.2)  // knob
    return m
  }

  static func pipe() -> Mesh {
    var m = Mesh()
    m.cylinderX(0, 0, 0, 0.5, 1.1, 0x6A, 0x8A, 0x9A)  // pipe
    m.cylinderX(0, 0, 0, 0.55, 0.12, darkGray.0, darkGray.1, darkGray.2)  // center band
    return m
  }

  static func shield() -> Mesh {
    var m = Mesh()
    m.box(0, 0, 0, 0.85, 1.0, 0.12, cyan.0, cyan.1, cyan.2)  // panel
    m.box(0, 0, 0.13, 0.5, 0.65, 0.03, white.0, white.1, white.2)  // emblem
    return m
  }

  static func teleport() -> Mesh {
    var m = Mesh()
    m.cylinderY(0, -0.8, 0, 0.9, 0.12, purple.0, purple.1, purple.2)  // base pad
    m.cylinderY(0, -0.55, 0, 0.7, 0.06, 0xC4, 0x8A, 0xE0)  // ring
    m.cylinderY(0, 0.1, 0, 0.32, 0.75, 0xC4, 0x8A, 0xE0)  // energy column
    return m
  }

  static func laser() -> Mesh {
    var m = Mesh()
    m.box(-0.85, 0, 0, 0.3, 0.45, 0.45, darkGray.0, darkGray.1, darkGray.2)  // emitter
    m.discZ(-0.54, 0, 0.0, 0.2, red.0, red.1, red.2)  // lens (front-ish)
    m.cylinderX(0.15, 0, 0, 0.07, 0.85, red.0, red.1, red.2)  // beam
    return m
  }

  static func jump() -> Mesh {
    var m = Mesh()
    m.box(0, -0.75, 0, 0.7, 0.15, 0.6, gray.0, gray.1, gray.2)  // base
    m.cylinderY(0, -0.35, 0, 0.4, 0.08, white.0, white.1, white.2)  // spring coils
    m.cylinderY(0, -0.05, 0, 0.4, 0.08, white.0, white.1, white.2)
    m.cylinderY(0, 0.25, 0, 0.4, 0.08, white.0, white.1, white.2)
    m.box(0, 0.55, 0, 0.6, 0.12, 0.5, green.0, green.1, green.2)  // top pad
    return m
  }
}
