#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import SceneKit

/// LEGO brick colors keyed by the game's `Entity.colorIndex`, matching the sprite families in
/// `RenderList.entitySprite` (0 white, 1 red, 2 green, 3 blue, 4 yellow, else the gray
/// "immobile"/fixed-terrain family). Ported from `tools/Junkbot3D/Sources/Junkbot3D/Palette.swift`
/// - that tool's macOS-only `NSColor` is generalized to `UIColor` on iOS/tvOS here, since this
/// module (unlike the offline tool) ships on all three.
enum Scene3DPalette {
  #if canImport(UIKit)
  typealias PlatformColor = UIColor
  #else
  typealias PlatformColor = NSColor
  #endif

  static func brickColor(colorIndex: Int32) -> PlatformColor {
    switch colorIndex {
    case 0: return rgb(0xF4, 0xF4, 0xF4)  // white
    case 1: return rgb(0xC4, 0x28, 0x1C)  // red
    case 2: return rgb(0x2C, 0x8C, 0x3C)  // green
    case 3: return rgb(0x1C, 0x54, 0xA8)  // blue
    case 4: return rgb(0xF4, 0xC4, 0x14)  // yellow
    default: return rgb(0x6C, 0x6C, 0x6C)  // gray immobile / fixed terrain
    }
  }

  static func rgb(_ r: Int, _ g: Int, _ b: Int) -> PlatformColor {
    PlatformColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
  }

  /// Matches `tools/Junkbot3D/Sources/Junkbot3D/Palette.swift`'s `.physicallyBased` material (and
  /// the baked LDraw entity models', via `swift-lego-draw`'s `LDrawMaterialCache`) exactly - not
  /// `.lambert`, which was tried first but is energy-*non-conserving*: with `locksAmbientWithDiffuse`
  /// summing the scene's bright ambient light on top of the directional light's diffuse term, faces
  /// clipped to a washed-out near-white instead of showing their true color. `.physicallyBased`
  /// needs `scene.lightingEnvironment` set (`Scene3DManager.init`) or its indirect-specular term has
  /// nothing to reflect and renders flat gray.
  static func material(_ color: PlatformColor) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = color
    m.lightingModel = .physicallyBased
    m.metalness.contents = 0.0
    m.roughness.contents = 0.35
    return m
  }
}
