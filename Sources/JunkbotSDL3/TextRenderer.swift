import CSDL3
import CSDL3Image
import Foundation
import JunkbotCore

/// Draws `JunkbotCore.Font`-laid-out bitmap text via SDL, reusing one texture (`font/font.png`,
/// a single row of white-alpha glyphs) for every color via `SDL_SetTextureColorMod` - the native
/// equivalent of `src/game.js`'s `colorizeWhiteAlphaImage` (which pre-bakes one tinted canvas per
/// color; SDL can just tint per draw call instead, so no pre-baking is needed here).
final class TextRenderer {
  private let renderer: OpaquePointer
  private let texture: UnsafeMutablePointer<SDL_Texture>?

  init(renderer: OpaquePointer, fontDirectory: URL) {
    self.renderer = renderer
    let url = fontDirectory.appendingPathComponent("font.png")
    guard let surface = IMG_Load(url.path) else {
      FileHandle.standardError.write(Data("Failed to load \(url.path)\n".utf8))
      texture = nil
      return
    }
    defer { SDL_DestroySurface(surface) }
    guard let texture = SDL_CreateTextureFromSurface(renderer, surface) else {
      FileHandle.standardError.write(
        Data("Failed to create font texture: \(String(cString: SDL_GetError()))\n".utf8))
      self.texture = nil
      return
    }
    _ = SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST)
    _ = SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND)
    self.texture = texture
  }

  /// Draws `text` with its top-left glyph origin at `(x, y)` in the renderer's current
  /// coordinate space (screen-space for menu UI, world-space for anything drawn during the
  /// world-viewport transform), tinted `color`. Returns the laid-out text's pixel size, useful
  /// for centering.
  @discardableResult
  func draw(_ text: String, x: Int32, y: Int32, color: SDL_Color, scale: Float = 1) -> (
    width: Int32, height: Int32
  ) {
    guard let texture else { return (0, 0) }
    _ = SDL_SetTextureColorMod(texture, color.r, color.g, color.b)
    if color.a != 255 {
      _ = SDL_SetTextureAlphaMod(texture, color.a)
    }

    let placements = Font.layoutText(text)
    var maxX: Int32 = 0
    var maxY: Int32 = Font.characterHeight
    for placement in placements {
      maxX = max(maxX, placement.x + placement.advance)
      maxY = max(maxY, placement.y + Font.characterHeight)
      guard let atlasIndex = placement.atlasIndex else { continue }
      var src = SDL_FRect(
        x: Float(Font.characterOffsets[atlasIndex]), y: 0,
        w: Float(Font.characterWidths[atlasIndex]), h: Float(Font.characterHeight))
      var dst = SDL_FRect(
        x: Float(x) + Float(placement.x) * scale, y: Float(y) + Float(placement.y) * scale,
        w: Float(Font.characterWidths[atlasIndex]) * scale, h: Float(Font.characterHeight) * scale)
      _ = SDL_RenderTexture(renderer, texture, &src, &dst)
    }

    if color.a != 255 {
      _ = SDL_SetTextureAlphaMod(texture, 255)
    }
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
      SDL_DestroyTexture(texture)
    }
  }
}
