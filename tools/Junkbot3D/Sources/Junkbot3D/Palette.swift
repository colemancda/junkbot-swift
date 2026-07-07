import SceneKit

/// LEGO brick colors keyed by the game's `Entity.colorIndex`, matching the sprite families in
/// `RenderList.entitySprite` (0 white, 1 red, 2 green, 3 blue, 4 yellow, else the gray
/// "immobile"/fixed-terrain family). RGB values approximate real LEGO colors rather than the
/// exact sprite-art pixels, since 3D shading (not flat sprites) determines the final look.
enum Palette {
  static func brickColor(colorIndex: Int32) -> NSColor {
    switch colorIndex {
    case 0: return rgb(0xF4, 0xF4, 0xF4)  // white
    case 1: return rgb(0xC4, 0x28, 0x1C)  // red
    case 2: return rgb(0x2C, 0x8C, 0x3C)  // green
    case 3: return rgb(0x1C, 0x54, 0xA8)  // blue
    case 4: return rgb(0xF4, 0xC4, 0x14)  // yellow
    default: return rgb(0x6C, 0x6C, 0x6C)  // gray immobile / fixed terrain
    }
  }

  static let enemyBody = rgb(0x9A, 0x9A, 0x9A)
  static let enemyAccent = rgb(0xC4, 0x28, 0x1C)
  static let binColor = rgb(0x3A, 0x8A, 0xC0)

  static func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(
      calibratedRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
  }

  /// A flat, unlit-ish LEGO plastic material. `.lambert` keeps shading cheap and matte, which
  /// reads as the low-poly PS1/DS look better than glossy `.blinn`/`.phong` highlights.
  static func material(_ color: NSColor) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = color
    m.lightingModel = .lambert
    m.locksAmbientWithDiffuse = true
    return m
  }
}
