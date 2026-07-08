// Vulkan counterpart of Darwin's `Metal3DManager.swift` for the live 3D play-mode view on
// Android - same call sites (`reset()`, `loadBackdrop(spriteID:)`,
// `loadLevelDecals(backgroundDecals:decals:)`, `sync(entities:)`, `syncCamera()`, `draw()`), same
// visual output (procedural bricks, the 15 baked LDraw entity models incl. Junkbot's animated
// walk-cycle legs, the backdrop image, level background decals, oblique-shear + orthographic
// camera framing, lighting ported from `three-stuff/3d-main.js`'s own scene setup).
//
// Reuses `Metal3DSpace.swift`/`Metal3DPalette.swift`/`Metal3DMatrix.swift`/`Metal3DModel.swift`/
// `Metal3DBrickGeometry.swift` unchanged (all `simd`/`Foundation`-only, no Metal dependency) via
// the `Sources/JunkbotSDL3` symlink shared with the desktop SDL3 port - see
// `ports/Android/Package.swift`'s `JunkbotGame` target, which already pulls those files in
// alongside every other shared game-loop source.
//
// No Swift/Vulkan wrapper package exists anywhere (checked): this talks to the raw C API
// (`CVulkan`, a hand-authored `.systemLibrary` bridging the NDK's own `vulkan/vulkan.h`, following
// `CAndroidLooper`'s exact pattern) directly. `PureSwift/SDL`'s `SDL3Swift` wrapper doesn't expose
// `SDL_Vulkan_*` either, so those are also called raw via `CSDL3` (transitively importable from
// any target depending on the `SDL3Swift` product - confirmed via `~/Downloads/
// PURESWIFT_SDL_GAPS.md`). `SDLWindow.internalPointer` is `internal` (this is a different module),
// so the actual `SDL_Window*` is recovered via the public `window.id` -> `SDL_GetWindowFromID`
// round-trip instead.
//
// Design tradeoffs (matching `Metal3DManager.swift`'s own documented choices):
// - One combined host-visible/coherent vertex buffer rebuilt every frame, one draw call for all
//   entities/bricks - simplicity over draw-call batching.
// - Textures use `VK_IMAGE_TILING_LINEAR` (skips a staging-buffer + transfer-command-buffer round
//   trip for the handful of small, non-mipmapped 2D textures this needs - backdrop, decals, the
//   chest emblem) - simplicity over the "correct" `OPTIMAL` + staging-buffer path.
// - Single frame in flight (fence-gated CPU/GPU sync each frame, no double-buffering) - simplicity
//   over pipelining.
// - Depth-stencil state is baked into 3 separate `VkPipeline` objects (entity: less/write;
//   backdrop+decal-layers: always/no-write; chest emblem: less-equal/no-write) rather than using
//   `VK_EXT_extended_dynamic_state`, since that extension's availability isn't guaranteed on every
//   API-28-era Vulkan-capable Android device - mirrors Metal's 3 `MTLDepthStencilState` objects,
//   just as 3 pipeline objects instead of one pipeline x 3 depth states, since core Vulkan bakes
//   depth-compare-op into the pipeline.
//
// Compositing with the existing 2D `SDL_Renderer` world: SDL's single-`SDL_Renderer` model has no
// Darwin-style transparent-view-stacking. `draw()` renders the 3D scene into its own swapchain-
// backed surface each frame (this manager owns its own `VkSwapchainKHR` against the shared
// window's `.vulkan`-flagged surface); the caller (`AndroidMain.swift`'s per-frame hook, mirroring
// Darwin's `GameScene.swift`) sets `suppressWorldSpriteDrawing` the same way Darwin does, so the
// 2D path's own `SDL_Renderer` pass skips world-sprite drawing while 3D is active - the two never
// draw into the same frame simultaneously (whichever one is active each tick owns the display).

import CSDL3
import CVulkan
import Foundation
import JunkbotCore

/// Plain stderr, not `AndroidLogging`'s `AndroidLogger` (an `JunkbotAndroid`-only dependency) -
/// this file lives in the shared `JunkbotGame` target (see this file's doc comment for why), which
/// intentionally has no Android-specific dependencies beyond `CVulkan` itself. Android's `SDLActivity`
/// redirects the process's stdout/stderr into logcat, so this still shows up there.
func log(_ message: String) { FileHandle.standardError.write(Data("\(message)\n".utf8)) }

@GameActor
final class Vulkan3DManager {
  // MARK: - Core Vulkan state

  let sdlWindow: OpaquePointer  // SDL_Window*
  var instance: VkInstance?
  var surface: VkSurfaceKHR?
  var physicalDevice: VkPhysicalDevice?
  var device: VkDevice?
  var queueFamilyIndex: UInt32 = 0
  var queue: VkQueue?

  var swapchain: VkSwapchainKHR?
  var swapchainFormat: VkFormat = VK_FORMAT_B8G8R8A8_UNORM
  var swapchainExtent = VkExtent2D(width: 0, height: 0)
  var swapchainImageViews: [VkImageView?] = []
  var framebuffers: [VkFramebuffer?] = []

  var renderPass: VkRenderPass?
  var depthImage: VkImage?
  var depthImageMemory: VkDeviceMemory?
  var depthImageView: VkImageView?

  var commandPool: VkCommandPool?
  var commandBuffer: VkCommandBuffer?
  var imageAvailableSemaphore: VkSemaphore?
  var renderFinishedSemaphore: VkSemaphore?
  var inFlightFence: VkFence?

  var descriptorSetLayout: VkDescriptorSetLayout?
  var descriptorPool: VkDescriptorPool?
  var sampler: VkSampler?

  var mainPipelineLayout: VkPipelineLayout?
  var mainPipeline: VkPipeline?
  var texturedPipelineLayout: VkPipelineLayout?
  var texturedPipelineAlways: VkPipeline?  // backdrop + background/foreground decals
  var texturedPipelineLessEqual: VkPipeline?  // chest emblem

  var vertexBuffer: VkBuffer?
  var vertexBufferMemory: VkDeviceMemory?
  var vertexBufferCapacityBytes: Int = 0

  // MARK: - Scene state (mirrors Metal3DManager.swift 1:1)

  let obliqueShear: float4x4
  var viewProjection: float4x4 = matrix_identity_float4x4
  var combinedVertices: [Metal3DVertex] = []

  struct GPUTexture {
    var image: VkImage?
    var memory: VkDeviceMemory?
    var view: VkImageView?
    var descriptorSet: VkDescriptorSet?
    var size: SIMD2<Float>
  }
  var textureCache: [Int32: GPUTexture] = [:]
  var junkbotDecalTexture: GPUTexture?

  var backdropTexture: GPUTexture?
  var backdropWorldPosition: SIMD3<Float> = .zero
  var loadedBackdropSpriteID: Int32 = -1
  var backgroundDecalQuads: [(texture: GPUTexture, worldPosition: SIMD3<Float>)] = []
  var foregroundDecalQuads: [(texture: GPUTexture, worldPosition: SIMD3<Float>)] = []
  var pendingDecalQuads: [(transform: float4x4, halfWidth: Float, halfHeight: Float)] = []

  private static let walkCycleLength: Int32 = 10
  private static let legSwingAmplitude: Float = .pi / 6

  struct TexturedVertex {
    var position: SIMD3<Float>
    var uv: SIMD2<Float>
  }

  // MARK: - Init

  /// `windowID` is `SDLWindow.id` (the only publicly-reachable handle to the underlying
  /// `SDL_Window*` from outside `SDL3Swift`'s own module - see this file's doc comment).
  init?(windowID: UInt32) {
    guard let sdlWindow = SDL_GetWindowFromID(windowID) else {
      log("Vulkan3DManager: SDL_GetWindowFromID failed")
      return nil
    }
    self.sdlWindow = sdlWindow

    // `cos`/`sin` only have a `Double` overload via Glibc on this platform (unlike Darwin's
    // Foundation, which also exposes `Float` overloads) - compute in `Double`, convert once.
    let alpha = Double.pi / 4
    let szx = Float(-0.5 * cos(alpha))
    let szy = Float(-0.5 * sin(alpha))
    obliqueShear = float4x4(
      columns: (
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(szx, szy, 1, 0),
        SIMD4<Float>(0, 0, 0, 1)
      ))

    guard
      createInstance(), createSurface(), pickPhysicalDeviceAndQueue(), createLogicalDevice(),
      createSwapchain(), createRenderPass(), createDepthResources(), createFramebuffers(),
      createCommandPoolAndBuffer(), createSyncObjects(), createDescriptorResources(),
      createPipelines()
    else {
      log("Vulkan3DManager: setup failed")
      return nil
    }
  }

  // MARK: - Public API (mirrors Metal3DManager.swift)

  func reset() {
    combinedVertices.removeAll()
  }

  func loadBackdrop(spriteID: Int32) {
    guard spriteID != loadedBackdropSpriteID else { return }
    loadedBackdropSpriteID = spriteID
    backdropTexture = nil
    guard let tex = spriteTexture(spriteID: spriteID) else { return }
    backdropTexture = tex
    let bx = -6 + tex.size.x / 2
    let by = -(-25 + tex.size.y / 2)
    backdropWorldPosition = SIMD3<Float>(bx, by, -500)
  }

  func loadLevelDecals(backgroundDecals: [DecalInstance], decals: [DecalInstance]) {
    func quads(
      _ instances: [DecalInstance], offsetX: Float, offsetY: Float, z: Float
    ) -> [(texture: GPUTexture, worldPosition: SIMD3<Float>)] {
      instances.compactMap { d in
        guard let tex = spriteTexture(spriteID: d.spriteID) else { return nil }
        let topLeftX = Float(d.x) - offsetX
        let topLeftY = Float(d.y) - offsetY
        let worldPosition = SIMD3<Float>(
          topLeftX + tex.size.x / 2, -(topLeftY + tex.size.y / 2), z)
        return (tex, worldPosition)
      }
    }
    backgroundDecalQuads = quads(backgroundDecals, offsetX: 3, offsetY: 20, z: -400)
    foregroundDecalQuads = quads(decals, offsetX: 30, offsetY: 64, z: -300)
  }

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
    let alpha: Float = e.grabbed ? (gameEngine.canRelease() ? 0.8 : 0.3) : 1.0
    appendLocal(local, transform: worldTransform, alphaOverride: alpha)
  }

  private func appendModel(_ model: Metal3DBakedModel, entity e: Entity, name: String) {
    let facing: Float = e.facing == 1 ? .pi / 2 : -.pi / 2
    let entityWorldTransform =
      obliqueShear * Metal3DMatrix.translation(Metal3DSpace.center(of: e))
      * Metal3DMatrix.rotationY(facing)

    let isRigged = name == "junkbot" && model.submeshes.count >= 3
    let swing: Float
    if isRigged {
      let phase: Float =
        2 * Float.pi * Float(e.animationFrame % Self.walkCycleLength)
        / Float(Self.walkCycleLength - 1)
      // `sin` only has a `Double` overload via Glibc on Linux/Android - see
      // `Metal3DMatrix.swift`'s `rotationX`/`rotationY` for the same fix.
      swing = Float(sin(Double(phase))) * Self.legSwingAmplitude
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
      if isRigged && i == 3 {
        queueChestDecal(bodySubmesh: submesh, entityWorldTransform: entityWorldTransform)
      }
    }
  }

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
    // See `Metal3DManager.swift`'s `queueChestDecal` for the full derivation - kept in sync there.
    let center = SIMD3<Float>(maxP.x + 0.5, (minP.y + maxP.y) / 2, (minP.z + maxP.z) / 2)
    let halfWidth = (maxP.z - minP.z) * 0.3
    let halfHeight = (maxP.y - minP.y) * 0.25
    guard halfWidth > 0, halfHeight > 0 else { return }
    let transform =
      entityWorldTransform * Metal3DMatrix.translation(center) * Metal3DMatrix.rotationY(.pi / 2)
    pendingDecalQuads.append((transform: transform, halfWidth: halfWidth, halfHeight: halfHeight))
  }

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

  /// Ports `Scene3DManager.syncCamera()`/`Metal3DManager.syncCamera()`'s exact orthographic-scale/
  /// position/look-at math.
  func syncCamera() {
    let canvasW = Float(windowWidth) / Float(cameraScale)
    let canvasH = Float(windowHeight) / Float(cameraScale)
    let viewAspect: Float =
      swapchainExtent.height > 0
      ? Float(swapchainExtent.width) / Float(swapchainExtent.height) : 1
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
}

/// One instance for the process's whole lifetime, matching `metal3DManager`'s lifecycle - lazily
/// initialized on first access (a plain top-level `let` with a closure/expression initializer, the
/// same pattern `window`/`renderer` in `GameMain.swift` already use), so it's built only once
/// `window` (referenced via `window.id` below) actually exists. `nil` if Vulkan setup fails for
/// any reason (missing driver, no Vulkan-capable GPU, ...) - `GameMain.swift`'s per-frame hook
/// treats that the same as "3D unavailable", falling back to nothing but the empty backdrop rather
/// than crashing (2D mode is unaffected either way).
@GameActor let vulkan3DManager: Vulkan3DManager? = Vulkan3DManager(windowID: UInt32(window.id))

/// Mirrors Darwin's `GameScene.swift`'s `scene3DWasActive` - tracks the *previous* tick's 3D-
/// active state so `GameMain.swift`'s per-frame hook only resets/reframes on an actual transition,
/// not every frame.
@GameActor var androidScene3DWasActive = false
