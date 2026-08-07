import SceneKit

/// LEGO brick colors keyed by the game's `Entity.colorIndex`, matching the sprite families in
/// `RenderList.entitySprite` (0 white, 1 red, 2 green, 3 blue, 4 yellow, else the gray
/// "immobile"/fixed-terrain family). RGB values are sampled directly from the sprite PNGs
/// (`images/sprites/brick_<name>_8.png` center pixel) so the diffuse base color itself is an
/// exact match - only the PBR shading (see `material` below) should account for any remaining
/// visual difference from the flat sprites.
enum Palette {
  static func brickColor(colorIndex: Int32) -> NSColor {
    switch colorIndex {
    case 0: return rgb(0xFF, 0xFF, 0xFF)  // white
    case 1: return rgb(0xCC, 0x00, 0x00)  // red
    case 2: return rgb(0x00, 0x80, 0x00)  // green
    case 3: return rgb(0x00, 0x33, 0xFF)  // blue
    case 4: return rgb(0xFF, 0xCC, 0x00)  // yellow
    default: return rgb(0x99, 0x99, 0x99)  // gray immobile / fixed terrain
    }
  }

  static let enemyBody = rgb(0x9A, 0x9A, 0x9A)
  static let enemyAccent = rgb(0xC4, 0x28, 0x1C)
  static let binColor = rgb(0x3A, 0x8A, 0xC0)

  static func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(
      calibratedRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
  }

  /// Matches the JS reference's LDraw-loaded parts, which three.js hands `MeshStandardMaterial`
  /// (a PBR material) rather than a flat/matte one - `.physicallyBased` is SceneKit's equivalent.
  /// LEGO plastic is a low-metalness, semi-glossy injection-molded surface: `metalness = 0` (it's
  /// not a metal, just plastic with a specular sheen) and a mid-low `roughness` so faces still
  /// pick up a soft specular highlight instead of PBR's default matte look. Needs
  /// `scene.lightingEnvironment` set (see `SceneBuilder.makeScene`) or PBR's indirect-specular
  /// term has nothing to reflect and renders flat gray.
  static func material(_ color: NSColor) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = color
    m.lightingModel = .physicallyBased
    m.metalness.contents = 0.0
    m.roughness.contents = 0.35
    return m
  }
}
