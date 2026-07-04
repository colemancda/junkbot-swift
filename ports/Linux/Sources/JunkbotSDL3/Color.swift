/// A plain, backend-agnostic RGBA color - used instead of naming `SDL_Color` directly in shared
/// drawing code (`Screens.swift`, `TextRenderer.swift`), since that's an SDL-version-specific
/// type name even though its layout happens to match between SDL2 and SDL3.
struct Color {
  var r, g, b, a: UInt8

  init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
    self.r = r
    self.g = g
    self.b = b
    self.a = a
  }

  static let black = Color(r: 0, g: 0, b: 0)
  static let white = Color(r: 255, g: 255, b: 255)
}
