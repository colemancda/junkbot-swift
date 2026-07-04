/// A plain, backend-agnostic RGBA color - used instead of naming `SDL_Color`/`SKColor` directly
/// in shared drawing code (`Screens.swift`, `TextRenderer.swift`), since those are
/// backend-specific type names even though `SDL_Color`'s layout happens to match between SDL2
/// and SDL3.
public struct Color: Sendable {
  public var r, g, b, a: UInt8

  public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
    self.r = r
    self.g = g
    self.b = b
    self.a = a
  }

  public static let black = Color(r: 0, g: 0, b: 0)
  public static let white = Color(r: 255, g: 255, b: 255)
}
