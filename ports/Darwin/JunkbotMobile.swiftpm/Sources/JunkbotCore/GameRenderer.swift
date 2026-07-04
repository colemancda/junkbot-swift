/// Backend-agnostic drawing primitives - the seam between the shared game-shell code
/// (`GameRender.swift`'s `renderWorld`/`render`, `Screens.swift`'s menu drawing,
/// `TextRenderer.swift`, the virtual-cursor drawing) and whichever backend actually renders it.
/// `ports/SDL3` implements this against SDL3 (`SDL3Renderer.swift`); `ports/SDL2` implements it
/// against SDL2 (`SDL2Renderer.swift`) - the two SDL C APIs disagree on almost every render
/// call's exact name/argument shape (`SDL_RenderTexture` vs `SDL_RenderCopyF`, float vs. integer
/// source rects, `SDL_FColor` vs `SDL_Color`, etc.); `ports/Darwin` implements it against
/// SpriteKit (`SpriteKitRenderer.swift`). This protocol is what lets the actual game/menu drawing
/// code live in exactly one shared file instead of two-or-three near-duplicates.
///
/// Textures are represented as a plain `OpaquePointer` rather than a named `SDL_Texture` type -
/// SDL2's `SDL_Texture` is a genuinely opaque forward declaration with no visible struct body,
/// which Swift's ClangImporter won't synthesize a nameable type for at all (unlike SDL3's, which
/// has real fields) - `OpaquePointer` is the one representation every backend can produce and
/// consume identically (SpriteKit's `SpriteKitRenderer` wraps a plain integer handle in one via
/// `OpaquePointer(bitPattern:)`), and nothing here ever needs to read a texture's fields directly
/// anyway.
///
/// Window creation, the event loop, audio, and OS hardware-cursor objects (`SDL_Cursor`) are
/// deliberately NOT part of this protocol - they're windowing/input/audio concerns, not
/// rendering, and stay platform-specific in each port's own `main.swift`/`Input.swift`.
public protocol GameRenderer: AnyObject {
  // MARK: - Textures

  /// Loads an image file into a texture, or `nil` on failure (missing file, decode error, etc.).
  func loadTexture(atPath path: String) -> OpaquePointer?
  func destroyTexture(_ texture: OpaquePointer)
  /// The texture's natural pixel size.
  func textureSize(_ texture: OpaquePointer) -> (width: Float, height: Float)
  /// Nearest-neighbor sampling - every backend defaults new textures to linear filtering, which
  /// blurs pixel art whenever a sprite isn't drawn at exact 1:1 scale (i.e. almost always, given
  /// camera zoom/offset).
  func setTextureNearestScaling(_ texture: OpaquePointer)
  /// `nil` restores full opacity (100).
  func setTextureAlpha(_ texture: OpaquePointer, percent: Int32?)
  /// Multiplies the texture's own pixels by this color on the next draw(s) - used to tint a
  /// single white-alpha bitmap-font atlas per call instead of pre-baking one texture per color.
  func setTextureColor(_ texture: OpaquePointer, r: UInt8, g: UInt8, b: UInt8)

  // MARK: - Frame lifecycle

  func clear(r: UInt8, g: UInt8, b: UInt8, a: UInt8)
  func present()

  // MARK: - Primitives (world/screen-space float coordinates, already camera/logical-scaled)

  func fillRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8)
  /// Unfilled outline, 1px.
  func strokeRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8)
  /// `src`, if given, clips/selects a sub-rectangle of the texture (atlas frame clipping, single
  /// glyph cells in a font atlas); `nil` draws the whole texture.
  func drawTexture(
    _ texture: OpaquePointer, src: (x: Float, y: Float, w: Float, h: Float)?,
    dstX: Float, dstY: Float, dstW: Float, dstH: Float, rotationDegrees: Double?)
  /// A filled, single-color triangle - the virtual cursor's fallback arrow shape.
  func fillTriangle(_ points: [(x: Float, y: Float)], r: UInt8, g: UInt8, b: UInt8, a: UInt8)

  // MARK: - Coordinate mapping

  /// Window-space (point) -> render-space (logical, post integer-scale/letterbox) coordinates.
  func windowToRender(x: Float, y: Float) -> (x: Float, y: Float)
  /// The inverse - needed wherever code warps the OS cursor (which takes window-space
  /// coordinates) from a render-space position.
  func renderToWindow(x: Float, y: Float) -> (x: Float, y: Float)
}
