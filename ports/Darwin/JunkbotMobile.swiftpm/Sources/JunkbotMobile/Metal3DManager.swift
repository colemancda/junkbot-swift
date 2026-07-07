import ImageIO
import JunkbotCore
import Metal
import MetalKit
import simd

/// Metal counterpart of `Scene3DManager.swift` for the live 3D play-mode view - same call sites
/// (`reset()`, `loadBackdrop(spriteID:)`, `sync(entities:)`, `syncCamera()`), same visual output
/// (procedural bricks, the 15 baked LDraw entity models incl. Junkbot's animated walk-cycle legs,
/// the backdrop image, oblique-shear + orthographic camera framing), built without SceneKit.
///
/// Design tradeoff: `swift-lego-draw`'s `LDrawMetal` renderer is a single-vertex-buffer/single-
/// draw-call design (built for a static-model orbit viewer, not a scene graph - see
/// `Metal3DShaderSource.swift`'s doc comment), so rather than reproduce SceneKit's per-node
/// incremental updates, `sync(entities:)` rebuilds **one combined vertex buffer** every frame:
/// every entity's baked/procedural local-space vertices get their world transform baked in on the
/// CPU (including, for Junkbot, the per-frame leg-rotation) and appended into one array, which
/// `draw(in:)` uploads and draws in a single call. Entity counts here are small enough (a
/// platformer level, not an open world) that this is not a performance concern - simplicity over
/// draw-call batching, not revisited unless it becomes one.
@MainActor
final class Metal3DManager: NSObject, MTKViewDelegate {
  private weak var mtkView: MTKView?

  private let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private let mainPipeline: MTLRenderPipelineState
  private let backdropPipeline: MTLRenderPipelineState
  private let entityDepthState: MTLDepthStencilState
  private let backdropDepthState: MTLDepthStencilState
  private let decalDepthState: MTLDepthStencilState
  private let samplerState: MTLSamplerState

  /// Junkbot's chest recycle emblem (`Metal3DDecalTextures.chestEmblem`) - the baked LDraw body
  /// brick carries no UVs to texture directly, so this is a small transparent-background quad
  /// drawn just in front of the body's own surface each frame `sync(entities:)` sees a Junkbot,
  /// same technique the offline tool's `DecalTextures.swift` uses for the trash bin's sticker.
  /// Built lazily (needs `device`, not available at property-init time) and cached for the
  /// process's lifetime - one flat-colored glyph, reused by every Junkbot instance.
  private var junkbotDecalTexture: MTLTexture?
  private var pendingDecalQuads: [(transform: float4x4, halfWidth: Float, halfHeight: Float)] = []

  /// Applied to entity content only, matching `Scene3DManager.worldNode`'s transform - the level
  /// backdrop stays unsheared (see `drawBackdrop`), same split as the SceneKit path.
  private let obliqueShear: float4x4

  private var backdropTexture: MTLTexture?
  private var backdropSize: SIMD2<Float> = .zero
  private var backdropWorldPosition: SIMD3<Float> = .zero
  private var loadedBackdropSpriteID: Int32 = -1

  private var combinedVertices: [Metal3DVertex] = []
  private var vertexBuffer: MTLBuffer?

  private var viewProjection: float4x4 = matrix_identity_float4x4

  private static let walkCycleLength: Int32 = 10
  private static let legSwingAmplitude: Float = .pi / 6

  /// Takes `device` as a parameter (rather than calling `MTLCreateSystemDefaultDevice()`
  /// internally with a bare `init?()`) so this doesn't collide with `NSObject`'s own non-failable
  /// `init()` - Swift forbids a failable override of a non-failable superclass initializer with
  /// the same signature.
  init?(device: MTLDevice) {
    guard let queue = device.makeCommandQueue() else {
      return nil
    }
    self.device = device
    self.commandQueue = queue

    guard let library = try? device.makeLibrary(source: Metal3DShaderSource, options: nil) else {
      return nil
    }

    guard
      let vertFn = library.makeFunction(name: "vertex_main"),
      let fragFn = library.makeFunction(name: "fragment_main")
    else { return nil }
    let vd = MTLVertexDescriptor()
    vd.attributes[0].format = .float3
    vd.attributes[0].offset = 0
    vd.attributes[0].bufferIndex = 0
    vd.attributes[1].format = .float3
    vd.attributes[1].offset = 16
    vd.attributes[1].bufferIndex = 0
    vd.attributes[2].format = .float4
    vd.attributes[2].offset = 32
    vd.attributes[2].bufferIndex = 0
    vd.layouts[0].stride = MemoryLayout<Metal3DVertex>.stride
    vd.layouts[0].stepFunction = .perVertex

    let pd = MTLRenderPipelineDescriptor()
    pd.vertexFunction = vertFn
    pd.fragmentFunction = fragFn
    pd.vertexDescriptor = vd
    pd.colorAttachments[0].pixelFormat = .bgra8Unorm
    pd.depthAttachmentPixelFormat = .depth32Float
    pd.colorAttachments[0].isBlendingEnabled = true
    pd.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pd.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    pd.colorAttachments[0].sourceAlphaBlendFactor = .one
    pd.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    guard let mainPipeline = try? device.makeRenderPipelineState(descriptor: pd) else { return nil }
    self.mainPipeline = mainPipeline

    guard
      let backdropVertFn = library.makeFunction(name: "backdrop_vertex_main"),
      let backdropFragFn = library.makeFunction(name: "backdrop_fragment_main")
    else { return nil }
    let bd = MTLVertexDescriptor()
    bd.attributes[0].format = .float3
    bd.attributes[0].offset = 0
    bd.attributes[0].bufferIndex = 0
    bd.attributes[1].format = .float2
    bd.attributes[1].offset = 16
    bd.attributes[1].bufferIndex = 0
    bd.layouts[0].stride = MemoryLayout<Metal3DBackdropVertex>.stride
    bd.layouts[0].stepFunction = .perVertex
    let bpd = MTLRenderPipelineDescriptor()
    bpd.vertexFunction = backdropVertFn
    bpd.fragmentFunction = backdropFragFn
    bpd.vertexDescriptor = bd
    bpd.colorAttachments[0].pixelFormat = .bgra8Unorm
    bpd.depthAttachmentPixelFormat = .depth32Float
    // Blending on: harmless for the (fully-opaque) backdrop PNG, and needed for the Junkbot decal
    // quad this same pipeline/vertex layout also draws (a transparent-background glyph - see
    // `drawTexturedQuad`).
    bpd.colorAttachments[0].isBlendingEnabled = true
    bpd.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    bpd.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    bpd.colorAttachments[0].sourceAlphaBlendFactor = .one
    bpd.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    guard let backdropPipeline = try? device.makeRenderPipelineState(descriptor: bpd) else {
      return nil
    }
    self.backdropPipeline = backdropPipeline

    let entityDS = MTLDepthStencilDescriptor()
    entityDS.depthCompareFunction = .less
    entityDS.isDepthWriteEnabled = true
    guard let entityDepthState = device.makeDepthStencilState(descriptor: entityDS) else {
      return nil
    }
    self.entityDepthState = entityDepthState

    // Backdrop always draws first, regardless of depth: matches `Scene3DManager`'s backdrop
    // sitting at very-negative-z with no shear, purely a background layer.
    let backdropDS = MTLDepthStencilDescriptor()
    backdropDS.depthCompareFunction = .always
    backdropDS.isDepthWriteEnabled = false
    guard let backdropDepthState = device.makeDepthStencilState(descriptor: backdropDS) else {
      return nil
    }
    self.backdropDepthState = backdropDepthState

    // Decals draw after entities, testing depth (so anything genuinely in front of Junkbot still
    // occludes the emblem) but not writing it (so drawing order among decals/entities afterward
    // doesn't matter).
    let decalDS = MTLDepthStencilDescriptor()
    decalDS.depthCompareFunction = .lessEqual
    decalDS.isDepthWriteEnabled = false
    guard let decalDepthState = device.makeDepthStencilState(descriptor: decalDS) else {
      return nil
    }
    self.decalDepthState = decalDepthState

    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.sAddressMode = .clampToEdge
    samplerDescriptor.tAddressMode = .clampToEdge
    guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
      return nil
    }
    self.samplerState = samplerState

    // Matches `Scene3DManager.init()`'s `worldNode.transform` exactly (janitorial-android
    // reference's oblique-projection shear, `alpha = pi/4`).
    let alpha = Float.pi / 4
    let szx = -0.5 * cos(alpha)
    let szy = -0.5 * sin(alpha)
    obliqueShear = float4x4(
      columns: (
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(szx, szy, 1, 0),
        SIMD4<Float>(0, 0, 0, 1)
      ))

    super.init()
  }

  /// Wires this manager up as `view`'s delegate/device - call once, when the view is created.
  func attach(to view: MTKView) {
    view.device = device
    view.delegate = self
    view.colorPixelFormat = .bgra8Unorm
    view.depthStencilPixelFormat = .depth32Float
    view.clearColor = MTLClearColorMake(0, 0, 0, 1)
    mtkView = view
  }

  /// Clears the accumulated frame state - call once per level load, mirroring
  /// `Scene3DManager.reset()` (there's no persistent node table to clear here, but the entry
  /// point is kept symmetric with the SceneKit path for `GameScene.swift`'s call site).
  func reset() {
    combinedVertices.removeAll()
  }

  // MARK: - Backdrop

  func loadBackdrop(spriteID: Int32) {
    guard spriteID != loadedBackdropSpriteID else { return }
    loadedBackdropSpriteID = spriteID
    backdropTexture = nil
    guard spriteID >= 0, spriteID < spriteNameTable.count else { return }
    let staticName = spriteNameTable[Int(spriteID)]
    let name = staticName.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
    guard !name.isEmpty else { return }

    let directories = [backgroundsDirectory, backgroundsUndercoverDirectory, spritesDirectory]
    var foundPath: String?
    for directory in directories {
      let path = directory.appendingPathComponent("\(name).png").path
      if FileManager.default.fileExists(atPath: path) {
        foundPath = path
        break
      }
    }
    guard let path = foundPath else { return }

    guard let texture = Self.loadTexture(path: path, device: device) else {
      FileHandle.standardError.write(Data("Metal3DManager: failed to load backdrop texture at \(path)\n".utf8))
      return
    }
    backdropTexture = texture
    backdropSize = SIMD2<Float>(Float(texture.width), Float(texture.height))
    // Matches `Scene3DManager.loadBackdrop(spriteID:)`: `RenderList.swift`'s backdrop command
    // draws the image's top-left at world (-6, -25), so its center is offset by half its size
    // from there.
    let bx = -6 + backdropSize.x / 2
    let by = -(-25 + backdropSize.y / 2)
    backdropWorldPosition = SIMD3<Float>(bx, by, -500)
  }

  // MARK: - Entity sync

  private static func modelName(for type: EntityType) -> String? {
    switch type {
    case .junkbot: return "junkbot"
    case .bin: return "bin"
    case .gearbot: return "gearbot"
    case .climbbot: return "climbbot"
    case .flybot: return "flybot"
    case .eyebot: return "eyebot"
    case .crate: return "crate"
    case .fire: return "fire"
    case .fan: return "fan"
    case .switch: return "switch"
    case .pipe: return "pipe"
    case .shield: return "shield"
    case .teleport: return "teleport"
    case .laser: return "laser"
    case .jump: return "jump"
    default: return nil
    }
  }

  func sync(entities: [Entity]) {
    combinedVertices.removeAll(keepingCapacity: true)
    pendingDecalQuads.removeAll(keepingCapacity: true)
    for e in entities {
      if e.type == .brick {
        appendBrick(e)
      } else if let name = Self.modelName(for: e.type), let model = Metal3DModelCache.model(named: name)
      {
        appendModel(model, entity: e, name: name)
      }
    }
  }

  private func appendBrick(_ e: Entity) {
    let local = Metal3DBrickGeometry.vertices(widthInStuds: e.widthInStuds, colorIndex: e.colorIndex)
    let worldTransform = obliqueShear * Metal3DMatrix.translation(Metal3DSpace.center(of: e))
    // Matches `RenderList.swift`'s `alpha: Int32 = e.grabbed ? (placeable ? 80 : 30) : 100` (the
    // 2D path's held-brick feedback) - 3D mode is play-only (never `.editing`, see
    // `Scene3DManager.swift`'s doc comment), so `placeable` there simplifies to `canRelease()`
    // alone.
    let alpha: Float = e.grabbed ? (gameEngine.canRelease() ? 0.8 : 0.3) : 1.0
    appendLocal(local, transform: worldTransform, alphaOverride: alpha)
  }

  private func appendModel(_ model: Metal3DBakedModel, entity e: Entity, name: String) {
    let facing: Float = e.facing == 1 ? .pi / 2 : -.pi / 2
    let entityWorldTransform =
      obliqueShear * Metal3DMatrix.translation(Metal3DSpace.center(of: e))
      * Metal3DMatrix.rotationY(facing)

    // Junkbot's baked submeshes are [hips, rightLeg, leftLeg, body, head, lid] (see
    // `Metal3DExporter.swift`'s doc comment) - indices 1/2 swing oppositely, driven by
    // `animationFrame`, mirroring `Scene3DManager.applyWalkCycle` exactly (same phase math,
    // dividing by `walkCycleLength - 1` so the last sampled frame lands back on neutral).
    let isRigged = name == "junkbot" && model.submeshes.count >= 3
    let swing: Float
    if isRigged {
      let phase =
        2 * Float.pi * Float(e.animationFrame % Self.walkCycleLength)
        / Float(Self.walkCycleLength - 1)
      swing = sin(phase) * Self.legSwingAmplitude
    } else {
      swing = 0
    }

    for (i, submesh) in model.submeshes.enumerated() {
      let legRotation: float4x4
      if isRigged && i == 1 {
        legRotation = Metal3DMatrix.rotationX(swing)
      } else if isRigged && i == 2 {
        legRotation = Metal3DMatrix.rotationX(-swing)
      } else {
        legRotation = matrix_identity_float4x4
      }
      let transform = entityWorldTransform * submesh.transformMatrix * legRotation
      appendBaked(submesh, transform: transform)
      // Body is submesh index 3 (see `Metal3DExporter.swift`'s doc comment for the fixed
      // hips/rightLeg/leftLeg/body/head/lid order) - queue the chest emblem quad just in front of
      // its own front (-z) face, sized to most of its footprint. Doesn't move with the leg rig
      // (only legs 1/2 are rigged), so uses `entityWorldTransform` directly, not `transform`.
      if isRigged && i == 3 {
        queueChestDecal(bodySubmesh: submesh, entityWorldTransform: entityWorldTransform)
      }
    }
  }

  /// Queues `junkbotDecalTexture`'s chest emblem on the body piece's own camera-facing side - see
  /// `Metal3DDecalTextures.swift`'s doc comment for why a flat quad instead of a real texture on
  /// the body's own (UV-less) baked geometry.
  private func queueChestDecal(bodySubmesh: Metal3DBakedSubmesh, entityWorldTransform: float4x4) {
    let count = bodySubmesh.vertexCount
    guard count > 0 else { return }
    let placement = bodySubmesh.transformMatrix
    var minP = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maxP = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    for idx in 0..<count {
      let local = SIMD3<Float>(
        bodySubmesh.positions[idx * 3], bodySubmesh.positions[idx * 3 + 1],
        bodySubmesh.positions[idx * 3 + 2])
      let p4 = placement * SIMD4<Float>(local, 1)
      let p = SIMD3<Float>(p4.x, p4.y, p4.z)
      minP = simd_min(minP, p)
      maxP = simd_max(maxP, p)
    }
    // `entityWorldTransform` includes `rotationY(facing)` (see `appendModel` - it turns the model
    // to face the level's travel axis instead of the offline preview's default camera-facing
    // pose), which maps body-*local* X straight to *world* Z (verified against
    // `Metal3DMatrix.rotationY`: for either `facing` sign, `world.z == local.x` exactly) - i.e.
    // once rotated, it's local X (the brick's own left-right width), not local Z, that ends up
    // facing toward/away from the camera. A decal offset along local Z (tried first) only nudges
    // it sideways and sits at the body's own mid-depth, so its own opaque geometry z-fights/
    // occludes it. Push to the body's local +X extreme instead (`maxP.x`, larger local x -> larger
    // world z -> closer to the camera at z=+1000) plus a small epsilon to clear the surface.
    let center = SIMD3<Float>(maxP.x + 0.5, (minP.y + maxP.y) / 2, (minP.z + maxP.z) / 2)
    // The quad spans body-local Y (vertical) and Z (lateral post-rotation, i.e. the body's own
    // depth extent, now facing along the travel axis) - halfWidth/halfHeight below name the local
    // Z/Y spans respectively; the extra `rotationY(.pi / 2)` factor below remaps
    // `drawTexturedQuad`'s local-XY-plane corners onto that Y/Z plane (local (x, y, 0) -> (0, y,
    // x), so the quad's own "x" axis lands on body-local Z, matching `halfWidth`).
    let halfWidth = (maxP.z - minP.z) * 0.3
    let halfHeight = (maxP.y - minP.y) * 0.25
    guard halfWidth > 0, halfHeight > 0 else { return }
    let transform =
      entityWorldTransform * Metal3DMatrix.translation(center) * Metal3DMatrix.rotationY(.pi / 2)
    pendingDecalQuads.append((transform: transform, halfWidth: halfWidth, halfHeight: halfHeight))
  }

  /// `alphaOverride`, when given, replaces (not multiplies) each vertex's own alpha - used for a
  /// grabbed brick's held/placeable feedback (see `appendBrick`) without baking that per-frame,
  /// per-entity state into `Metal3DBrickGeometry`'s (studs, color)-keyed cache.
  private func appendLocal(_ local: [Metal3DVertex], transform: float4x4, alphaOverride: Float? = nil)
  {
    combinedVertices.reserveCapacity(combinedVertices.count + local.count)
    for v in local {
      let p = transform * SIMD4<Float>(v.position, 1)
      let n = transform * SIMD4<Float>(v.normal, 0)
      var color = v.color
      if let alphaOverride { color.w = alphaOverride }
      combinedVertices.append(
        Metal3DVertex(
          position: SIMD3<Float>(p.x, p.y, p.z),
          normal: simd_normalize(SIMD3<Float>(n.x, n.y, n.z)), color: color))
    }
  }

  private func appendBaked(_ submesh: Metal3DBakedSubmesh, transform: float4x4) {
    let count = submesh.vertexCount
    combinedVertices.reserveCapacity(combinedVertices.count + count)
    for idx in 0..<count {
      let p = SIMD3<Float>(
        submesh.positions[idx * 3], submesh.positions[idx * 3 + 1], submesh.positions[idx * 3 + 2])
      let n = SIMD3<Float>(
        submesh.normals[idx * 3], submesh.normals[idx * 3 + 1], submesh.normals[idx * 3 + 2])
      let c = SIMD4<Float>(
        submesh.colors[idx * 4], submesh.colors[idx * 4 + 1], submesh.colors[idx * 4 + 2],
        submesh.colors[idx * 4 + 3])
      let wp = transform * SIMD4<Float>(p, 1)
      let wn = transform * SIMD4<Float>(n, 0)
      combinedVertices.append(
        Metal3DVertex(
          position: SIMD3<Float>(wp.x, wp.y, wp.z),
          normal: simd_normalize(SIMD3<Float>(wn.x, wn.y, wn.z)), color: c))
    }
  }

  // MARK: - Camera

  /// Ports `Scene3DManager.syncCamera()`'s exact orthographic-scale/position/look-at math to an
  /// explicit view+projection matrix.
  func syncCamera() {
    let canvasW = Float(windowWidth) / Float(cameraScale)
    let canvasH = Float(windowHeight) / Float(cameraScale)
    let viewBounds = mtkView?.bounds ?? CGRect(x: 0, y: 0, width: CGFloat(canvasW), height: CGFloat(canvasH))
    let viewAspect: Float = viewBounds.height > 0 ? Float(viewBounds.width / viewBounds.height) : 1
    let canvasAspect: Float = canvasH > 0 ? canvasW / canvasH : 1
    let halfHeight: Float = viewAspect >= canvasAspect ? canvasH / 2 : (canvasW / 2) / viewAspect

    let cx = Float(cameraCenterX)
    let cy = -Float(cameraCenterY)
    let eye = SIMD3<Float>(cx, cy, 1000)
    let target = SIMD3<Float>(cx, cy, 0)
    let view = Metal3DMatrix.lookAt(eye: eye, center: target, up: SIMD3<Float>(0, 1, 0))
    let proj = Metal3DMatrix.orthographic(halfHeight: halfHeight, aspect: viewAspect, near: 1, far: 4000)
    viewProjection = proj * view
  }

  // MARK: - MTKViewDelegate

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    guard
      let drawable = view.currentDrawable,
      let rpd = view.currentRenderPassDescriptor,
      let cmdBuf = commandQueue.makeCommandBuffer(),
      let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
    else { return }

    if let texture = backdropTexture {
      drawBackdrop(enc, texture: texture)
    }

    if !combinedVertices.isEmpty {
      let byteCount = combinedVertices.count * MemoryLayout<Metal3DVertex>.stride
      if vertexBuffer == nil || vertexBuffer!.length < byteCount {
        vertexBuffer = device.makeBuffer(length: byteCount, options: .storageModeShared)
      }
      if let buffer = vertexBuffer {
        combinedVertices.withUnsafeBytes { raw in
          buffer.contents().copyMemory(from: raw.baseAddress!, byteCount: raw.count)
        }
        enc.setRenderPipelineState(mainPipeline)
        enc.setDepthStencilState(entityDepthState)
        enc.setVertexBuffer(buffer, offset: 0, index: 0)
        // Positions/normals baked into world space already (see this file's doc comment) - only
        // the camera's view-projection remains; `normalMatrix` is identity.
        var uniforms = Metal3DUniforms(
          modelViewProjection: viewProjection, normalMatrix: matrix_identity_float4x4)
        enc.setVertexBytes(&uniforms, length: MemoryLayout<Metal3DUniforms>.size, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: combinedVertices.count)
      }
    }

    if !pendingDecalQuads.isEmpty {
      if junkbotDecalTexture == nil {
        junkbotDecalTexture = Metal3DDecalTextures.chestEmblem(
          strokeColor: SIMD4<Float>(0.45, 0.24, 0.06, 1), device: device)
      }
      if let texture = junkbotDecalTexture {
        for quad in pendingDecalQuads {
          drawTexturedQuad(
            enc, texture: texture, transform: quad.transform, halfWidth: quad.halfWidth,
            halfHeight: quad.halfHeight, depthState: decalDepthState)
        }
      }
    }

    enc.endEncoding()
    cmdBuf.present(drawable)
    cmdBuf.commit()
  }

  /// `MTKTextureLoader` fails outright ("Image decoding failed") on this project's backdrop PNGs
  /// - they're 8-bit indexed/colormap PNGs, a format it apparently can't decode - so this decodes
  /// via `CGImageSource`/`CGContext` into a plain RGBA8 buffer instead, which handles any PNG
  /// color format, then uploads that buffer directly.
  private static func loadTexture(path: String, device: MTLDevice) -> MTLTexture? {
    guard
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }

    let width = cgImage.width, height = cgImage.height
    guard width > 0, height > 0 else { return nil }

    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
      let context = CGContext(
        data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    // Flip vertically: `CGContext`'s origin is bottom-left, but the pixel buffer we upload below
    // needs top-left-origin row order (matches the backdrop quad's UVs, which assume that too).
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
    descriptor.usage = .shaderRead
    guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
    texture.replace(
      region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels,
      bytesPerRow: bytesPerRow)
    return texture
  }

  private func drawBackdrop(_ enc: MTLRenderCommandEncoder, texture: MTLTexture) {
    let hw = backdropSize.x / 2, hh = backdropSize.y / 2
    let p = backdropWorldPosition
    let quad: [Metal3DBackdropVertex] = [
      .init(position: SIMD3(p.x - hw, p.y - hh, p.z), uv: SIMD2(0, 1)),
      .init(position: SIMD3(p.x + hw, p.y - hh, p.z), uv: SIMD2(1, 1)),
      .init(position: SIMD3(p.x + hw, p.y + hh, p.z), uv: SIMD2(1, 0)),
      .init(position: SIMD3(p.x - hw, p.y - hh, p.z), uv: SIMD2(0, 1)),
      .init(position: SIMD3(p.x + hw, p.y + hh, p.z), uv: SIMD2(1, 0)),
      .init(position: SIMD3(p.x - hw, p.y + hh, p.z), uv: SIMD2(0, 0)),
    ]
    enc.setRenderPipelineState(backdropPipeline)
    enc.setDepthStencilState(backdropDepthState)
    quad.withUnsafeBytes { raw in
      enc.setVertexBytes(raw.baseAddress!, length: raw.count, index: 0)
    }
    // Backdrop is unsheared (see this file's doc comment): view-projection only, no oblique shear.
    var mvp = viewProjection
    enc.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.size, index: 1)
    enc.setFragmentTexture(texture, index: 0)
    enc.setFragmentSamplerState(samplerState, index: 0)
    enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quad.count)
  }

  /// Draws a `halfWidth`x`halfHeight` quad in `transform`'s local XY plane (unlike
  /// `drawBackdrop`'s axis-aligned quad, `transform` here carries an arbitrary rotation - the
  /// decal needs to sit flush against and rotate with its entity's own front face).
  private func drawTexturedQuad(
    _ enc: MTLRenderCommandEncoder, texture: MTLTexture, transform: float4x4, halfWidth: Float,
    halfHeight: Float, depthState: MTLDepthStencilState
  ) {
    func corner(_ x: Float, _ y: Float) -> SIMD3<Float> {
      let p = transform * SIMD4<Float>(x, y, 0, 1)
      return SIMD3<Float>(p.x, p.y, p.z)
    }
    let c00 = corner(-halfWidth, -halfHeight)
    let c10 = corner(halfWidth, -halfHeight)
    let c11 = corner(halfWidth, halfHeight)
    let c01 = corner(-halfWidth, halfHeight)
    let quad: [Metal3DBackdropVertex] = [
      .init(position: c00, uv: SIMD2(0, 1)),
      .init(position: c10, uv: SIMD2(1, 1)),
      .init(position: c11, uv: SIMD2(1, 0)),
      .init(position: c00, uv: SIMD2(0, 1)),
      .init(position: c11, uv: SIMD2(1, 0)),
      .init(position: c01, uv: SIMD2(0, 0)),
    ]
    enc.setRenderPipelineState(backdropPipeline)
    enc.setDepthStencilState(depthState)
    quad.withUnsafeBytes { raw in
      enc.setVertexBytes(raw.baseAddress!, length: raw.count, index: 0)
    }
    var mvp = viewProjection
    enc.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.size, index: 1)
    enc.setFragmentTexture(texture, index: 0)
    enc.setFragmentSamplerState(samplerState, index: 0)
    enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quad.count)
  }
}

private struct Metal3DBackdropVertex {
  var position: SIMD3<Float>
  var uv: SIMD2<Float>
}

/// One instance for the process's whole lifetime, matching `scene3DManager`'s lifecycle. `nil` on
/// a machine/VM with no Metal-capable GPU (the SceneKit path, still in the tree, would be the
/// fallback there - not wired up automatically, since every real Mac this ships to has Metal).
@GameActor let metal3DManager: Metal3DManager? = MTLCreateSystemDefaultDevice().flatMap {
  Metal3DManager(device: $0)
}

/// The `MTKView` created by the macOS entry point (`AppDelegate_macOS.swift`) - `nil` until then,
/// matching `scnView`'s lazy-assignment pattern.
@GameActor var metalView: MTKView?
