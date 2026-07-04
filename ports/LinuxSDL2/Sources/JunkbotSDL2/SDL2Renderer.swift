import CSDL2
import CSDL2Image
import Foundation

/// `GameRenderer` implemented against SDL2's `SDL_Render*`/`IMG_*` API. See `Renderer.swift` for
/// why this seam exists. Where SDL2's API shape genuinely differs from SDL3's (float vs. integer
/// source rects, `SDL_RenderCopyF` vs `SDL_RenderTexture`, `SDL_Color` vs `SDL_FColor` vertex
/// colors, `SDL_QueryTexture` vs `SDL_GetTextureSize`), that difference is absorbed entirely
/// here - nothing above this file needs to know about it.
final class SDL2Renderer: GameRenderer {
  let sdlRenderer: OpaquePointer

  init(sdlRenderer: OpaquePointer) {
    self.sdlRenderer = sdlRenderer
  }

  func loadTexture(atPath path: String) -> OpaquePointer? {
    guard let texture = IMG_LoadTexture(sdlRenderer, path) else { return nil }
    _ = SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND)
    return texture
  }

  func destroyTexture(_ texture: OpaquePointer) {
    SDL_DestroyTexture(texture)
  }

  func textureSize(_ texture: OpaquePointer) -> (width: Float, height: Float) {
    var w: Int32 = 0
    var h: Int32 = 0
    _ = SDL_QueryTexture(texture, nil, nil, &w, &h)
    return (Float(w), Float(h))
  }

  func setTextureNearestScaling(_ texture: OpaquePointer) {
    _ = SDL_SetTextureScaleMode(texture, SDL_ScaleModeNearest)
  }

  func setTextureAlpha(_ texture: OpaquePointer, percent: Int32?) {
    let clamped = max(0, min(100, percent ?? 100))
    _ = SDL_SetTextureAlphaMod(texture, UInt8(clamped * 255 / 100))
  }

  func setTextureColor(_ texture: OpaquePointer, r: UInt8, g: UInt8, b: UInt8) {
    _ = SDL_SetTextureColorMod(texture, r, g, b)
  }

  func clear(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    _ = SDL_SetRenderDrawColor(sdlRenderer, r, g, b, a)
    _ = SDL_RenderClear(sdlRenderer)
  }

  func present() {
    SDL_RenderPresent(sdlRenderer)
  }

  func fillRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    _ = SDL_SetRenderDrawColor(sdlRenderer, r, g, b, a)
    var rect = SDL_FRect(x: x, y: y, w: w, h: h)
    _ = SDL_RenderFillRectF(sdlRenderer, &rect)
  }

  func strokeRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    _ = SDL_SetRenderDrawColor(sdlRenderer, r, g, b, a)
    var rect = SDL_FRect(x: x, y: y, w: w, h: h)
    _ = SDL_RenderDrawRectF(sdlRenderer, &rect)
  }

  func drawTexture(
    _ texture: OpaquePointer, src: (x: Float, y: Float, w: Float, h: Float)?,
    dstX: Float, dstY: Float, dstW: Float, dstH: Float, rotationDegrees: Double?
  ) {
    var dst = SDL_FRect(x: dstX, y: dstY, w: dstW, h: dstH)
    // SDL2's *CopyF variants keep the SOURCE rect as integer pixel coordinates (SDL_Rect) - only
    // the destination is subpixel (SDL_FRect).
    var srcRect: SDL_Rect? = src.map {
      SDL_Rect(x: Int32($0.x), y: Int32($0.y), w: Int32($0.w), h: Int32($0.h))
    }
    if let rotationDegrees {
      withUnsafeMutablePointer(to: &dst) { dstPtr in
        if srcRect != nil {
          _ = SDL_RenderCopyExF(
            sdlRenderer, texture, &srcRect!, dstPtr, rotationDegrees, nil, SDL_FLIP_NONE)
        } else {
          _ = SDL_RenderCopyExF(
            sdlRenderer, texture, nil, dstPtr, rotationDegrees, nil, SDL_FLIP_NONE)
        }
      }
    } else if srcRect != nil {
      _ = SDL_RenderCopyF(sdlRenderer, texture, &srcRect!, &dst)
    } else {
      _ = SDL_RenderCopyF(sdlRenderer, texture, nil, &dst)
    }
  }

  func fillTriangle(_ points: [(x: Float, y: Float)], r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    let color = SDL_Color(r: r, g: g, b: b, a: a)
    var vertices = points.map {
      SDL_Vertex(
        position: SDL_FPoint(x: $0.x, y: $0.y), color: color, tex_coord: SDL_FPoint(x: 0, y: 0))
    }
    _ = SDL_RenderGeometry(sdlRenderer, nil, &vertices, Int32(vertices.count), nil, 0)
  }

  func windowToRender(x: Float, y: Float) -> (x: Float, y: Float) {
    var renderX: Float = 0
    var renderY: Float = 0
    SDL_RenderWindowToLogical(sdlRenderer, Int32(x), Int32(y), &renderX, &renderY)
    return (renderX, renderY)
  }

  func renderToWindow(x: Float, y: Float) -> (x: Float, y: Float) {
    var windowX: Int32 = 0
    var windowY: Int32 = 0
    SDL_RenderLogicalToWindow(sdlRenderer, x, y, &windowX, &windowY)
    return (Float(windowX), Float(windowY))
  }
}
