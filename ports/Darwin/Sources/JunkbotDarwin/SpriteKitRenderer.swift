import SpriteKit
import JunkbotCore

/// `GameRenderer` implemented against SpriteKit, used purely as an immediate-mode blitter - no
/// `SKPhysicsBody`/`SKPhysicsWorld` anywhere; `GameEngine`/`JunkbotCore` remains the sole
/// simulation authority (see `GameScene.swift`, which only ever calls `gameEngine.tick()`, never
/// touches an `SKPhysicsWorld`). Each draw call adds a fresh `SKNode` to the scene; `clear()`
/// removes every node added by the previous frame - the same "redraw the whole command list every
/// frame" model `SDL3Renderer`/`SDL2Renderer` already use, reimplemented on top of a fundamentally
/// retained scene graph via node churn.
///
/// `GameRenderer`'s texture type is `OpaquePointer` (chosen for SDL2's opaque-C-struct import
/// limitation - see `Renderer.swift`). SpriteKit has no such constraint (`SKTexture` is a
/// perfectly nameable Swift class), so textures are tracked in a side table keyed by a small
/// integer handle, and `OpaquePointer(bitPattern:)` wraps that integer purely to satisfy the
/// protocol's type signature - the bit pattern is never dereferenced, only round-tripped back
/// through `Int(bitPattern:)` to look the texture up, so this is safe despite looking like a raw
/// pointer.
///
/// Coordinate system: SpriteKit is Y-up with the origin at the scene's bottom-left; every other
/// backend (and the whole `GameRenderer` protocol contract) is Y-down with the origin at the
/// top-left. `flippedY(_:height:)` converts at every draw call, including inside texture-rect
/// sub-region clipping.
@MainActor final class SpriteKitRenderer: @preconcurrency GameRenderer {
  private weak var scene: SKScene?
  private weak var view: SKView?

  private var texturesByHandle: [Int: SKTexture] = [:]
  private var alphaByHandle: [Int: Float] = [:]
  private var colorByHandle: [Int: SKColor] = [:]
  private var nextHandle = 1

  /// Nodes added since the last `clear()` - removed wholesale at the start of the next frame.
  private var frameNodes: [SKNode] = []

  init(scene: SKScene, view: SKView) {
    self.scene = scene
    self.view = view
  }

  private func newHandle(for texture: SKTexture) -> OpaquePointer {
    let handle = nextHandle
    nextHandle += 1
    texturesByHandle[handle] = texture
    return OpaquePointer(bitPattern: handle)!
  }

  private func texture(_ pointer: OpaquePointer) -> SKTexture? {
    texturesByHandle[Int(bitPattern: pointer)]
  }

  /// Scene-space (Y-up, origin bottom-left) from this protocol's Y-down top-left convention.
  private func flippedY(_ y: Float, height: Float) -> Float {
    guard let sceneHeight = scene?.size.height else { return y }
    return Float(sceneHeight) - y - height
  }

  // MARK: - Textures

  func loadTexture(atPath path: String) -> OpaquePointer? {
    #if canImport(UIKit)
    guard let image = UIImage(contentsOfFile: path) else { return nil }
    let texture = SKTexture(image: image)
    #else
    guard let image = NSImage(contentsOfFile: path) else { return nil }
    let texture = SKTexture(image: image)
    #endif
    return newHandle(for: texture)
  }

  func destroyTexture(_ texture: OpaquePointer) {
    let handle = Int(bitPattern: texture)
    texturesByHandle.removeValue(forKey: handle)
    alphaByHandle.removeValue(forKey: handle)
    colorByHandle.removeValue(forKey: handle)
  }

  func textureSize(_ texture: OpaquePointer) -> (width: Float, height: Float) {
    guard let t = self.texture(texture) else { return (0, 0) }
    return (Float(t.size().width), Float(t.size().height))
  }

  func setTextureNearestScaling(_ texture: OpaquePointer) {
    self.texture(texture)?.filteringMode = .nearest
  }

  /// `nil` restores full opacity - stored per-handle since SpriteKit applies alpha per-node
  /// (`SKSpriteNode.alpha`) at actual draw time, not per-texture like SDL's `*AlphaMod`.
  func setTextureAlpha(_ texture: OpaquePointer, percent: Int32?) {
    let handle = Int(bitPattern: texture)
    guard let percent else {
      alphaByHandle.removeValue(forKey: handle)
      return
    }
    alphaByHandle[handle] = Float(max(0, min(100, percent))) / 100
  }

  /// Multiplies the texture's pixels by this color on the next draw(s) - `SKSpriteNode.color` +
  /// `colorBlendFactor = 1` reproduces SDL's `*ColorMod` tinting for a white-alpha bitmap-font
  /// atlas.
  func setTextureColor(_ texture: OpaquePointer, r: UInt8, g: UInt8, b: UInt8) {
    colorByHandle[Int(bitPattern: texture)] = SKColor(
      red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
  }

  // MARK: - Frame lifecycle

  func clear(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    scene?.backgroundColor = SKColor(
      red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    for node in frameNodes { node.removeFromParent() }
    frameNodes.removeAll(keepingCapacity: true)
  }

  func present() {
    // No-op: SpriteKit composites automatically via its own display-link-driven render loop -
    // nodes added by this frame's draw calls are already live in the scene graph by this point.
  }

  // MARK: - Primitives

  func fillRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    guard let scene else { return }
    let node = SKShapeNode(
      rect: CGRect(x: CGFloat(x), y: CGFloat(flippedY(y, height: h)), width: CGFloat(w), height: CGFloat(h)))
    node.fillColor = SKColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    node.strokeColor = .clear
    node.zPosition = CGFloat(frameNodes.count)
    scene.addChild(node)
    frameNodes.append(node)
  }

  func strokeRect(x: Float, y: Float, w: Float, h: Float, r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    guard let scene else { return }
    let node = SKShapeNode(
      rect: CGRect(x: CGFloat(x), y: CGFloat(flippedY(y, height: h)), width: CGFloat(w), height: CGFloat(h)))
    node.fillColor = .clear
    node.strokeColor = SKColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    node.lineWidth = 1
    node.zPosition = CGFloat(frameNodes.count)
    scene.addChild(node)
    frameNodes.append(node)
  }

  func drawTexture(
    _ texture: OpaquePointer, src: (x: Float, y: Float, w: Float, h: Float)?,
    dstX: Float, dstY: Float, dstW: Float, dstH: Float, rotationDegrees: Double?
  ) {
    guard let scene, let baseTexture = self.texture(texture) else { return }

    var drawTexture = baseTexture
    if let src {
      // `SKTexture(rect:in:)`'s rect is normalized (0...1) against the *original* texture's own
      // size and, like the rest of SpriteKit, Y-up with origin at the texture's bottom-left - so
      // the sub-rect's y needs flipping against the texture's own height, not the scene's.
      let fullSize = baseTexture.size()
      let flippedSrcY = Float(fullSize.height) - src.y - src.h
      let normalized = CGRect(
        x: CGFloat(src.x) / fullSize.width, y: CGFloat(flippedSrcY) / fullSize.height,
        width: CGFloat(src.w) / fullSize.width, height: CGFloat(src.h) / fullSize.height)
      drawTexture = SKTexture(rect: normalized, in: baseTexture)
    }

    let node = SKSpriteNode(texture: drawTexture, size: CGSize(width: CGFloat(dstW), height: CGFloat(dstH)))
    // SKSpriteNode's default anchorPoint is its center; the protocol's dstX/dstY are top-left -
    // shift by half the size (post-flip) to compensate.
    node.position = CGPoint(
      x: CGFloat(dstX) + CGFloat(dstW) / 2, y: CGFloat(flippedY(dstY, height: dstH)) + CGFloat(dstH) / 2)
    let handle = Int(bitPattern: texture)
    if let alpha = alphaByHandle[handle] {
      node.alpha = CGFloat(alpha)
    }
    if let color = colorByHandle[handle] {
      node.color = color
      node.colorBlendFactor = 1
    }
    if let rotationDegrees {
      // SpriteKit's `zRotation` is counterclockwise radians; every other backend here rotates
      // clockwise degrees (matching SDL's `SDL_RenderTextureRotated`) - negate to match, on top
      // of the Y-flip already applied to position.
      node.zRotation = CGFloat(-rotationDegrees * .pi / 180)
    }
    node.zPosition = CGFloat(frameNodes.count)
    scene.addChild(node)
    frameNodes.append(node)
  }

  func fillTriangle(_ points: [(x: Float, y: Float)], r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    guard let scene, points.count >= 3 else { return }
    let path = CGMutablePath()
    let first = points[0]
    path.move(to: CGPoint(x: CGFloat(first.x), y: CGFloat(flippedY(first.y, height: 0))))
    for point in points.dropFirst() {
      path.addLine(to: CGPoint(x: CGFloat(point.x), y: CGFloat(flippedY(point.y, height: 0))))
    }
    path.closeSubpath()
    let node = SKShapeNode(path: path)
    node.fillColor = SKColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    node.strokeColor = .clear
    node.zPosition = CGFloat(frameNodes.count)
    scene.addChild(node)
    frameNodes.append(node)
  }

  // MARK: - Coordinate mapping

  func windowToRender(x: Float, y: Float) -> (x: Float, y: Float) {
    guard let view, let scene else { return (x, y) }
    let scenePoint = view.convert(CGPoint(x: CGFloat(x), y: CGFloat(y)), to: scene)
    // `convert(_:to:)` already applies SpriteKit's own scene-scaling/letterboxing transform - only
    // the Y-up -> Y-down flip (this protocol's convention) remains.
    return (Float(scenePoint.x), Float(scene.size.height) - Float(scenePoint.y))
  }

  func renderToWindow(x: Float, y: Float) -> (x: Float, y: Float) {
    guard let view, let scene else { return (x, y) }
    let scenePoint = CGPoint(x: CGFloat(x), y: CGFloat(scene.size.height) - CGFloat(y))
    let viewPoint = view.convert(scenePoint, from: scene)
    return (Float(viewPoint.x), Float(viewPoint.y))
  }
}
