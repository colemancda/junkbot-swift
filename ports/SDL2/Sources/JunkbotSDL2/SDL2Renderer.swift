import CSDL2
import SDL2Swift
import SDL2Image
import JunkbotCore

/// `GameRenderer` implemented against `SDL2Swift`'s `SDLRenderer`/`SDLTexture` wrapper types
/// (and `SDL2Image`'s `SDLTexture(renderer:contentsOfFile:)` for loading) instead of raw
/// `SDL_Render*`/`IMG_*` calls. See `JunkbotCore/GameRenderer.swift` for why this seam exists.
///
/// Two SDL2-specific quirks the wrapper faithfully preserves, absorbed entirely in this file:
/// - `SDLRenderer.fill(rect:)`/`draw(rect:)`/the non-rotated `copy(_:source:destination:)`
///   overloads all take integer `SDL_Rect` (matching classic `SDL_RenderFillRect`/
///   `SDL_RenderDrawRect`/`SDL_RenderCopy`, not the subpixel `*F` variants) - `fillRect`/
///   `strokeRect` fall back to the raw `SDL_RenderFillRectF`/`SDL_RenderDrawRectF` C calls via
///   `renderer.unsafePointer` to keep subpixel precision (camera offsets aren't always
///   whole-pixel). `drawTexture` instead always routes through the *rotated* `copy(_:source:
///   destination:angle:...)` overload (passing `angle: 0` when no rotation is needed), since
///   that overload's `destination` is already a subpixel `SDL_FRect` even on SDL2 - avoiding the
///   raw-pointer fallback there entirely, since SDL2's `SDLTexture` (unlike SDL3's) doesn't
///   expose its own raw pointer.
final class SDL2Renderer: GameRenderer {
  let renderer: SDLRenderer

  private var texturesByHandle: [Int: SDLTexture] = [:]
  private var nextHandle = 1

  init(renderer: SDLRenderer) {
    self.renderer = renderer
  }

  private func newHandle(for texture: SDLTexture) -> OpaquePointer {
    let handle = nextHandle
    nextHandle += 1
    texturesByHandle[handle] = texture
    return OpaquePointer(bitPattern: handle)!
  }

  private func texture(_ pointer: OpaquePointer) -> SDLTexture? {
    texturesByHandle[Int(bitPattern: pointer)]
  }

  func loadTexture(atPath path: String) -> OpaquePointer? {
    guard let texture = try? SDLTexture(renderer: renderer, contentsOfFile: path) else { return nil }
    try? texture.setBlendMode([.alpha])
    return newHandle(for: texture)
  }

  func destroyTexture(_ texture: OpaquePointer) {
    texturesByHandle.removeValue(forKey: Int(bitPattern: texture))
  }

  func textureSize(_ texture: OpaquePointer) -> (width: Float, height: Float) {
    guard let attributes = try? self.texture(texture)?.attributes() else { return (0, 0) }
    return (Float(attributes.width), Float(attributes.height))
  }

  func setTextureNearestScaling(_ texture: OpaquePointer) {
    try? self.texture(texture)?.setScaleMode(.nearest)
  }

  func setTextureAlpha(_ texture: OpaquePointer, percent: Int32?) {
    let clamped = max(0, min(100, percent ?? 100))
    try? self.texture(texture)?.setAlphaModulation(UInt8(clamped * 255 / 100))
  }

  func setTextureColor(_ texture: OpaquePointer, r: UInt8, g: UInt8, b: UInt8) {
    try? self.texture(texture)?.setColorModulation(red: r, green: g, blue: b)
  }

  func clear(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    try? renderer.setDrawColor(red: r, green: g, blue: b, alpha: a)
    try? renderer.clear()
  }

  func present() {
    renderer.present()
  }

  func fillRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    // SDL2's renderer draw blend mode defaults to `SDL_BLENDMODE_NONE`, which ignores the alpha
    // channel entirely and draws fully opaque - unlike SDL3, which blends draw-color alpha by
    // default. Without this, the win/lose dialog's semi-transparent black backdrop (and any
    // other translucent fill/stroke) renders fully opaque, hiding the world behind it.
    try? renderer.setDrawBlendMode([.alpha])
    try? renderer.setDrawColor(red: r, green: g, blue: b, alpha: a)
    var rect = SDL_FRect(x: x, y: y, w: w, h: h)
    _ = SDL_RenderFillRectF(renderer.unsafePointer, &rect)
  }

  func strokeRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    try? renderer.setDrawBlendMode([.alpha])
    try? renderer.setDrawColor(red: r, green: g, blue: b, alpha: a)
    var rect = SDL_FRect(x: x, y: y, w: w, h: h)
    _ = SDL_RenderDrawRectF(renderer.unsafePointer, &rect)
  }

  func drawTexture(
    _ texture: OpaquePointer, src: (x: Float, y: Float, w: Float, h: Float)?,
    dstX: Float, dstY: Float, dstW: Float, dstH: Float, rotationDegrees: Double?
  ) {
    guard let sdlTexture = self.texture(texture) else { return }
    let dst = SDL_FRect(x: dstX, y: dstY, w: dstW, h: dstH)
    // SDL2's *CopyF variants keep the SOURCE rect as integer pixel coordinates (SDL_Rect) - only
    // the destination is subpixel (SDL_FRect) - matches the original hand-written renderer here,
    // not a regression (atlas-frame clip rects are already integer-aligned in practice).
    let srcRect: SDL_Rect? = src.map {
      SDL_Rect(x: Int32($0.x), y: Int32($0.y), w: Int32($0.w), h: Int32($0.h))
    }
    // Always routes through the *rotated* copy overload (angle 0 when no rotation is needed):
    // it's the only one whose destination rect is subpixel-precise even on SDL2, and SDL2's
    // `SDLTexture` doesn't expose a raw pointer the way SDL3's does, so there's no raw-call
    // fallback available here the way `fillRect`/`strokeRect` have.
    try? renderer.copy(sdlTexture, source: srcRect, destination: dst, angle: rotationDegrees ?? 0)
  }

  func fillTriangle(_ points: [(x: Float, y: Float)], r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    let color = SDLRenderer.VertexColor(
      red: Float(r) / 255, green: Float(g) / 255, blue: Float(b) / 255, alpha: Float(a) / 255)
    let vertices = points.map { (position: SDL_FPoint(x: $0.x, y: $0.y), color: color) }
    try? renderer.drawGeometry(vertices: vertices)
  }

  func windowToRender(x: Float, y: Float) -> (x: Float, y: Float) {
    renderer.renderCoordinates(fromWindow: (x, y))
  }

  func renderToWindow(x: Float, y: Float) -> (x: Float, y: Float) {
    renderer.windowCoordinates(fromRender: (x, y))
  }
}
