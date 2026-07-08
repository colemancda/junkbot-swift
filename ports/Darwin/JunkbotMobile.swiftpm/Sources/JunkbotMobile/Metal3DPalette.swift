#if canImport(simd)
import simd
#endif

/// `Metal3D*`'s counterpart to `Scene3DPalette.swift` - same color table (matching
/// `RenderList.entitySprite`'s sprite families) as plain RGBA rather than a platform color/
/// `SCNMaterial`, so the Metal path never imports SceneKit at all.
enum Metal3DPalette {
  static func brickColor(colorIndex: Int32) -> SIMD4<Float> {
    switch colorIndex {
    case 0: return rgb(0xF4, 0xF4, 0xF4)  // white
    case 1: return rgb(0xC4, 0x28, 0x1C)  // red
    case 2: return rgb(0x2C, 0x8C, 0x3C)  // green
    case 3: return rgb(0x1C, 0x54, 0xA8)  // blue
    case 4: return rgb(0xF4, 0xC4, 0x14)  // yellow
    default: return rgb(0x6C, 0x6C, 0x6C)  // gray immobile / fixed terrain
    }
  }

  static let black = SIMD4<Float>(0, 0, 0, 1)
  /// Brick edge-outline color (`Metal3DBrickGeometry.edgeOutline`) - 90% transparent so the
  /// silhouette lines read as a subtle seam rather than a hard black stroke.
  static let outline = SIMD4<Float>(0, 0, 0, 0.1)

  static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD4<Float> {
    SIMD4<Float>(Float(r) / 255, Float(g) / 255, Float(b) / 255, 1)
  }
}
