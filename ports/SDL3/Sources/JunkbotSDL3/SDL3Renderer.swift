import CSDL3
import CSDL3Image
import Foundation

/// `GameRenderer` implemented against SDL3's `SDL_Render*`/`IMG_*` API. See `Renderer.swift` for
/// why this seam exists.
final class SDL3Renderer: GameRenderer {
  let sdlRenderer: OpaquePointer

  init(sdlRenderer: OpaquePointer) {
    self.sdlRenderer = sdlRenderer
  }

  func loadTexture(atPath path: String) -> OpaquePointer? {
    guard let texture = IMG_LoadTexture(sdlRenderer, path) else { return nil }
    _ = SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND)
    return OpaquePointer(texture)
  }

  func destroyTexture(_ texture: OpaquePointer) {
    SDL_DestroyTexture(UnsafeMutablePointer<SDL_Texture>(texture))
  }

  func textureSize(_ texture: OpaquePointer) -> (width: Float, height: Float) {
    var w: Float = 0
    var h: Float = 0
    _ = SDL_GetTextureSize(UnsafeMutablePointer<SDL_Texture>(texture), &w, &h)
    return (w, h)
  }

  func setTextureNearestScaling(_ texture: OpaquePointer) {
    _ = SDL_SetTextureScaleMode(UnsafeMutablePointer<SDL_Texture>(texture), SDL_SCALEMODE_NEAREST)
  }

  func setTextureAlpha(_ texture: OpaquePointer, percent: Int32?) {
    let clamped = max(0, min(100, percent ?? 100))
    _ = SDL_SetTextureAlphaMod(
      UnsafeMutablePointer<SDL_Texture>(texture), UInt8(clamped * 255 / 100))
  }

  func setTextureColor(_ texture: OpaquePointer, r: UInt8, g: UInt8, b: UInt8) {
    _ = SDL_SetTextureColorMod(UnsafeMutablePointer<SDL_Texture>(texture), r, g, b)
  }

  func clear(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    _ = SDL_SetRenderDrawColor(sdlRenderer, r, g, b, a)
    _ = SDL_RenderClear(sdlRenderer)
  }

  func present() {
    SDL_RenderPresent(sdlRenderer)
  }

  func fillRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    _ = SDL_SetRenderDrawBlendMode(sdlRenderer, SDL_BLENDMODE_BLEND)
    _ = SDL_SetRenderDrawColor(sdlRenderer, r, g, b, a)
    var rect = SDL_FRect(x: x, y: y, w: w, h: h)
    _ = SDL_RenderFillRect(sdlRenderer, &rect)
  }

  func strokeRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    _ = SDL_SetRenderDrawBlendMode(sdlRenderer, SDL_BLENDMODE_BLEND)
    _ = SDL_SetRenderDrawColor(sdlRenderer, r, g, b, a)
    var rect = SDL_FRect(x: x, y: y, w: w, h: h)
    _ = SDL_RenderRect(sdlRenderer, &rect)
  }

  func drawTexture(
    _ texture: OpaquePointer, src: (x: Float, y: Float, w: Float, h: Float)?,
    dstX: Float, dstY: Float, dstW: Float, dstH: Float, rotationDegrees: Double?
  ) {
    let sdlTexture = UnsafeMutablePointer<SDL_Texture>(texture)
    var dst = SDL_FRect(x: dstX, y: dstY, w: dstW, h: dstH)
    var srcRect: SDL_FRect? = src.map { SDL_FRect(x: $0.x, y: $0.y, w: $0.w, h: $0.h) }
    if let rotationDegrees {
      withUnsafeMutablePointer(to: &dst) { dstPtr in
        if srcRect != nil {
          _ = SDL_RenderTextureRotated(
            sdlRenderer, sdlTexture, &srcRect!, dstPtr, rotationDegrees, nil, SDL_FLIP_NONE)
        } else {
          _ = SDL_RenderTextureRotated(
            sdlRenderer, sdlTexture, nil, dstPtr, rotationDegrees, nil, SDL_FLIP_NONE)
        }
      }
    } else if srcRect != nil {
      _ = SDL_RenderTexture(sdlRenderer, sdlTexture, &srcRect!, &dst)
    } else {
      _ = SDL_RenderTexture(sdlRenderer, sdlTexture, nil, &dst)
    }
  }

  func fillTriangle(_ points: [(x: Float, y: Float)], r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    let color = SDL_FColor(
      r: Float(r) / 255, g: Float(g) / 255, b: Float(b) / 255, a: Float(a) / 255)
    var vertices = points.map {
      SDL_Vertex(
        position: SDL_FPoint(x: $0.x, y: $0.y), color: color, tex_coord: SDL_FPoint(x: 0, y: 0))
    }
    _ = SDL_RenderGeometry(sdlRenderer, nil, &vertices, Int32(vertices.count), nil, 0)
  }

  func windowToRender(x: Float, y: Float) -> (x: Float, y: Float) {
    var renderX: Float = 0
    var renderY: Float = 0
    _ = SDL_RenderCoordinatesFromWindow(sdlRenderer, x, y, &renderX, &renderY)
    return (renderX, renderY)
  }

  func renderToWindow(x: Float, y: Float) -> (x: Float, y: Float) {
    var windowX: Float = 0
    var windowY: Float = 0
    _ = SDL_RenderCoordinatesToWindow(sdlRenderer, x, y, &windowX, &windowY)
    return (windowX, windowY)
  }
}
