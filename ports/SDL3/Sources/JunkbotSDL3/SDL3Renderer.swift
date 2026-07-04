import CSDL3
import SDL3Swift
import SDL3Image
import JunkbotCore

/// `GameRenderer` implemented against `SDL3Swift`'s `SDLRenderer`/`SDLTexture` wrapper types
/// (and `SDL3Image`'s `SDLTexture(renderer:contentsOfFile:)` for loading) instead of raw
/// `SDL_Render*`/`IMG_*` calls. See `JunkbotCore/GameRenderer.swift` for why this seam exists.
///
/// Textures are represented as a plain `OpaquePointer` rather than a named `SDLTexture` (chosen
/// for SDL2's opaque-C-struct import limitation - see that protocol's doc comment), so this
/// class tracks `SDLTexture` instances in a side table keyed by a small integer handle, and
/// wraps that integer in an `OpaquePointer(bitPattern:)` purely to satisfy the protocol's type
/// signature - the same technique `ports/Darwin`'s `SpriteKitRenderer` uses for `SKTexture`. The
/// bit pattern is never dereferenced, only round-tripped back through `Int(bitPattern:)`.
final class SDL3Renderer: GameRenderer {
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
    try? renderer.setDrawBlendMode([.alpha])
    try? renderer.setDrawColor(red: r, green: g, blue: b, alpha: a)
    try? renderer.fill(rect: SDL_FRect(x: x, y: y, w: w, h: h))
  }

  func strokeRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    try? renderer.setDrawBlendMode([.alpha])
    try? renderer.setDrawColor(red: r, green: g, blue: b, alpha: a)
    try? renderer.draw(rect: SDL_FRect(x: x, y: y, w: w, h: h))
  }

  func drawTexture(
    _ texture: OpaquePointer, src: (x: Float, y: Float, w: Float, h: Float)?,
    dstX: Float, dstY: Float, dstW: Float, dstH: Float, rotationDegrees: Double?
  ) {
    guard let sdlTexture = self.texture(texture) else { return }
    let dst = SDL_FRect(x: dstX, y: dstY, w: dstW, h: dstH)
    let srcRect: SDL_FRect? = src.map { SDL_FRect(x: $0.x, y: $0.y, w: $0.w, h: $0.h) }
    if let rotationDegrees {
      try? renderer.copy(sdlTexture, source: srcRect, destination: dst, angle: rotationDegrees)
    } else if let srcRect {
      try? renderer.copy(sdlTexture, source: srcRect, destination: dst)
    } else {
      try? renderer.copy(sdlTexture, destination: dst)
    }
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
