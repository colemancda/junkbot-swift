import JunkbotCore
import SceneKit

/// Drives the live 3D play-mode view: a *persistent* `SCNScene` kept in sync with
/// `GameEngine.entities` every tick, unlike the offline `tools/Junkbot3D` preview (which rebuilds
/// its whole scene from one static entity snapshot per invocation). Bricks are the same procedural
/// mesh that tool uses (`Scene3DBrickGeometry`); every other entity type loads one of the 15
/// `.scn` files baked by `tools/Junkbot3D --bake-all` (real official LEGO parts via
/// `swift-lego-draw`, precompiled since the live app can't ship the 600MB LDraw library or parse
/// `.ldr` files at runtime - see that tool's `main.swift` for the baking step).
///
/// Scope (per the 3D-mode plan): play mode only. The level editor's drag-to-place interaction
/// stays on the existing 2D `SpriteKitRenderer` path; this manager is only active while
/// `currentScreen == .playing` and the render-mode preference is 3D (see `Settings.swift`,
/// `GameScene.swift`).
@MainActor
final class Scene3DManager {
  let scene = SCNScene()
  let cameraNode = SCNNode()

  /// Persistent entity-id -> node table, so `sync(entities:)` only touches what actually changed
  /// since the last tick (new/removed entities), rather than tearing down and rebuilding
  /// everything - smooth animation (Junkbot walking, bricks being dragged) needs stable node
  /// identity, not per-frame node churn like the 2D `SpriteKitRenderer`'s "redraw everything"
  /// model.
  private var nodesByEntityID: [Int32: SCNNode] = [:]

  /// One loaded-and-cached template per bundled `.scn` (or per brick width+color, inside
  /// `Scene3DBrickGeometry`'s own cache) - `node(for:)` clones from here instead of re-parsing the
  /// scene file every time an entity of that type appears.
  private var modelCache: [String: SCNNode] = [:]

  init() {
    let camera = SCNCamera()
    camera.usesOrthographicProjection = true
    camera.zNear = 1
    camera.zFar = 4000
    cameraNode.camera = camera
    scene.rootNode.addChildNode(cameraNode)

    let ambient = SCNLight()
    ambient.type = .ambient
    ambient.color = Scene3DPalette.rgb(0xB0, 0xB0, 0xB8)
    let ambientNode = SCNNode()
    ambientNode.light = ambient
    scene.rootNode.addChildNode(ambientNode)

    let sun = SCNLight()
    sun.type = .directional
    sun.color = Scene3DPalette.rgb(0xFF, 0xFF, 0xF0)
    sun.castsShadow = false  // PS1/DS-era: no dynamic shadows, keeps the flat low-poly look.
    let sunNode = SCNNode()
    sunNode.light = sun
    sunNode.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
    scene.rootNode.addChildNode(sunNode)
  }

  /// Entity type -> baked `.scn` resource name, matching
  /// `tools/Junkbot3D/Sources/Junkbot3D/SceneBuilder.swift`'s `ldrawModelName(for:)` list exactly
  /// (same 15 types have models; `.brick` is procedural; `.droplet` has none yet).
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

  private func loadedModel(named name: String) -> SCNNode? {
    if let cached = modelCache[name] { return cached.clone() }
    guard
      let url = Bundle.main.url(forResource: name, withExtension: "scn", subdirectory: "Models3D")
        ?? Bundle.main.url(forResource: name, withExtension: "scn"),
      let bakedScene = try? SCNScene(url: url, options: nil),
      let node = bakedScene.rootNode.childNodes.first
    else { return nil }
    modelCache[name] = node
    return node.clone()
  }

  private func node(for e: Entity) -> SCNNode? {
    if e.type == .brick {
      return Scene3DBrickGeometry.node(widthInStuds: e.widthInStuds, colorIndex: e.colorIndex)
    }
    guard let name = Self.modelName(for: e.type) else { return nil }
    return loadedModel(named: name)
  }

  /// Clears every tracked node and starts fresh - call once per level load, since entity IDs
  /// reset (`GameEngine.loadLevel*`) and stale nodes from the previous level would otherwise
  /// linger under IDs that now mean something else.
  func reset() {
    for node in nodesByEntityID.values { node.removeFromParentNode() }
    nodesByEntityID.removeAll()
  }

  /// Adds nodes for new entities, updates position/facing for existing ones, and removes nodes
  /// for entities that disappeared (collected bins, popped droplets, etc.) - cheap enough to call
  /// every tick.
  func sync(entities: [Entity]) {
    var seenIDs = Set<Int32>()
    seenIDs.reserveCapacity(entities.count)

    for e in entities {
      seenIDs.insert(e.id)
      if let existing = nodesByEntityID[e.id] {
        existing.position = Scene3DSpace.center(of: e)
        if e.type != .brick {
          existing.eulerAngles.y = e.facing == 1 ? .pi / 2 : -.pi / 2
        }
        continue
      }
      guard let newNode = node(for: e) else { continue }
      newNode.position = Scene3DSpace.center(of: e)
      if e.type != .brick {
        newNode.eulerAngles.y = e.facing == 1 ? .pi / 2 : -.pi / 2
      }
      scene.rootNode.addChildNode(newNode)
      nodesByEntityID[e.id] = newNode
    }

    for (id, node) in nodesByEntityID where !seenIDs.contains(id) {
      node.removeFromParentNode()
      nodesByEntityID.removeValue(forKey: id)
    }
  }

  /// Frames the camera straight-on (looking down -z at the z=0 plane every entity sits on), with
  /// `orthographicScale` fit to the *live* `SCNView` aspect ratio the same way the 2D path's
  /// `SKScene` (`.aspectFit`) fits the level's logical size into the window - matching this
  /// exactly (rather than an angle, or an aspect-agnostic `spanX/spanY * constant` heuristic) is
  /// what makes the visible 3D geometry land exactly where the 2D mouse-drag hit-testing
  /// (`GameInput.swift`, `JunkbotCore/Input.swift` - unaware of 3D, works purely in world pixel
  /// coordinates) expects it. A tilted/isometric camera was tried and reverted: tilting shears an
  /// orthographic projection of a flat z=0 scene relative to that flat 2D hit-testing space, so
  /// bricks/Junkbot would visually sit somewhere other than their true (2D) grab area no matter
  /// how the scale is tuned - only a straight-on camera projects with the uniform, aspect-correct
  /// scale 2D hit-testing assumes. Call once per level load and whenever the view resizes.
  func frameCamera(entities: [Entity], bounds: LevelBounds?) {
    var minX = CGFloat.greatestFiniteMagnitude
    var minY = CGFloat.greatestFiniteMagnitude
    var maxX = -CGFloat.greatestFiniteMagnitude
    var maxY = -CGFloat.greatestFiniteMagnitude
    if let b = bounds {
      minX = CGFloat(b.x)
      minY = CGFloat(b.y)
      maxX = CGFloat(b.x + b.width)
      maxY = CGFloat(b.y + b.height)
    } else {
      for e in entities {
        minX = min(minX, CGFloat(e.x))
        minY = min(minY, CGFloat(e.y))
        maxX = max(maxX, CGFloat(e.x + e.width))
        maxY = max(maxY, CGFloat(e.y + e.height))
      }
      if minX > maxX {
        minX = 0
        minY = 0
        maxX = 100
        maxY = 100
      }
    }
    let cx = (minX + maxX) / 2
    let cy = -(minY + maxY) / 2
    let spanX = maxX - minX
    let spanY = maxY - minY

    // Fit `spanX` x `spanY` into the view the same way `.aspectFit` fits the SKScene into the
    // window: fit to whichever axis is the limiting one, so nothing gets cropped and the other
    // axis gets extra (letterboxed) space - never a flat, aspect-agnostic scale constant.
    let viewBounds = scnView?.bounds ?? CGRect(x: 0, y: 0, width: spanX, height: spanY)
    let viewAspect = viewBounds.height > 0 ? viewBounds.width / viewBounds.height : 1
    let levelAspect = spanY > 0 ? spanX / spanY : 1
    let halfHeight: CGFloat =
      viewAspect >= levelAspect ? spanY / 2 : (spanX / 2) / viewAspect
    cameraNode.camera?.orthographicScale = Double(halfHeight)

    cameraNode.position = SCNVector3(cx, cy, 1000)
    cameraNode.look(at: SCNVector3(cx, cy, 0))
  }
}

/// One instance for the process's whole lifetime - matches every other engine-adjacent global in
/// `GameShell.swift` (`gameEngine`, `soundBoard`, etc).
@GameActor let scene3DManager = Scene3DManager()

/// The `SCNView` created by whichever platform entry point builds the view hierarchy
/// (`GameViewController.swift`'s `loadView()`, `AppDelegate_macOS.swift`) - `nil` until then,
/// same lazy-assignment pattern as `gameRenderer`. `JunkbotScene.update(_:)` toggles
/// `scnView.isHidden` each frame based on `Settings.render3DEnabled` and `currentScreen`.
@GameActor var scnView: SCNView?
