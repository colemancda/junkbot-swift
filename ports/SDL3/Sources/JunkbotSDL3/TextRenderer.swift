import Foundation
import JunkbotCore

/// Draws `JunkbotCore.Font`-laid-out bitmap text via the shared `GameRenderer`, reusing one
/// texture (`font/font.png`, a single row of white-alpha glyphs) for every color via
/// `GameRenderer.setTextureColor` - the native equivalent of `src/game.js`'s
/// `colorizeWhiteAlphaImage` (which pre-bakes one tinted canvas per color; SDL can just tint per
/// draw call instead, so no pre-baking is needed here).
final class TextRenderer {
  private let renderer: GameRenderer
  private let texture: OpaquePointer?

  init(renderer: GameRenderer, fontDirectory: URL) {
    self.renderer = renderer
    let url = fontDirectory.appendingPathComponent("font.png")
    guard let texture = renderer.loadTexture(atPath: url.path) else {
      FileHandle.standardError.write(Data("Failed to load \(url.path)\n".utf8))
      self.texture = nil
      return
    }
    renderer.setTextureNearestScaling(texture)
    self.texture = texture
  }

  /// Draws `text` with its top-left glyph origin at `(x, y)` in the renderer's current
  /// coordinate space (screen-space for menu UI, world-space for anything drawn during the
  /// world-viewport transform), tinted `color`. Returns the laid-out text's pixel size, useful
  /// for centering.
  @discardableResult
  func draw(_ text: String, x: Int32, y: Int32, color: Color, scale: Float = 1) -> (
    width: Int32, height: Int32
  ) {
    guard let texture else { return (0, 0) }
    renderer.setTextureColor(texture, r: color.r, g: color.g, b: color.b)
    let alphaPercent: Int32? = color.a != 255 ? Int32(color.a) * 100 / 255 : nil
    renderer.setTextureAlpha(texture, percent: alphaPercent)

    let placements = Font.layoutText(text)
    var maxX: Int32 = 0
    var maxY: Int32 = Font.characterHeight
    for placement in placements {
      maxX = max(maxX, placement.x + placement.advance)
      maxY = max(maxY, placement.y + Font.characterHeight)
      guard let atlasIndex = placement.atlasIndex else { continue }
      let src = (
        x: Float(Font.characterOffsets[atlasIndex]), y: Float(0),
        w: Float(Font.characterWidths[atlasIndex]), h: Float(Font.characterHeight)
      )
      renderer.drawTexture(
        texture, src: src,
        dstX: Float(x) + Float(placement.x) * scale, dstY: Float(y) + Float(placement.y) * scale,
        dstW: Float(Font.characterWidths[atlasIndex]) * scale,
        dstH: Float(Font.characterHeight) * scale, rotationDegrees: nil)
    }

    renderer.setTextureAlpha(texture, percent: nil)
    return (maxX, maxY)
  }

  /// The pixel size `text` would occupy if drawn, without actually drawing it - for centering/
  /// hit-testing before a real draw call.
  func measure(_ text: String) -> (width: Int32, height: Int32) {
    let placements = Font.layoutText(text)
    var maxX: Int32 = 0
    var maxY: Int32 = Font.characterHeight
    for placement in placements {
      maxX = max(maxX, placement.x + placement.advance)
      maxY = max(maxY, placement.y + Font.characterHeight)
    }
    return (maxX, maxY)
  }

  deinit {
    if let texture {
      renderer.destroyTexture(texture)
    }
  }
}
