import JunkbotCore
import SceneKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

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

  /// Every entity node is parented here, not directly under `scene.rootNode` - this is what the
  /// oblique-shear transform (set in `init`) applies to, so the camera itself (added straight to
  /// `scene.rootNode`, not `worldNode`) stays untilted and its projection keeps the uniform,
  /// aspect-correct scale 2D hit-testing (`GameInput.swift`, `JunkbotCore/Input.swift`) assumes.
  /// See `init`'s comment for where the shear itself comes from.
  let worldNode = SCNNode()

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

  /// The level backdrop image (`RenderList.swift`'s `backdropSpriteID`, drawn as a 2D sprite at
  /// world `(-6, -25)` in the 2D path) as a flat plane, added directly to `scene.rootNode` -
  /// *not* `worldNode` - so it isn't pushed sideways by `worldNode`'s oblique-shear transform: that
  /// shear only displaces a child node by its own local z times the shear factor, and every entity
  /// sits at local z=0 (only their baked geometry has nonzero-z depth, which *is* shear-displaced,
  /// giving bricks their slanted-side look) - so keeping this flat backdrop unsheared at the same
  /// z=0-equivalent x/y still lines up with the (also effectively unshifted) entities in front of
  /// it, just sitting behind them at very negative z. Since the camera is a straight orthographic
  /// projection, that z difference alone doesn't affect x/y screen position.
  private let backdropNode = SCNNode()
  private var loadedBackdropSpriteID: Int32 = -1

  init() {
    let camera = SCNCamera()
    camera.usesOrthographicProjection = true
    camera.zNear = 1
    camera.zFar = 4000
    cameraNode.camera = camera
    scene.rootNode.addChildNode(cameraNode)

    // The real 2D game's own "3D-ish" look, per `three-stuff/3d-main.js`'s `obliqueProjection`
    // GUI option (`Syx=0, Szx=-0.5*cos(pi/4), Sxy=0, Szy=-0.5*sin(pi/4), Sxz=0, Syz=0` sheared
    // into the projection matrix there) - ported here as `tools/Junkbot3D`'s
    // `SceneBuilder.obliqueShearTransform()`/`--front` mode already does, applied to the *content*
    // (`worldNode`) instead of the camera's projection matrix so a straight orthographic camera
    // still does the projecting: shearing the camera/projection instead would tilt the same flat
    // (z=0) 2D hit-testing space that broke the earlier isometric-camera attempt.
    let alpha = Double.pi / 4
    let szx = CGFloat(-0.5 * cos(alpha))
    let szy = CGFloat(-0.5 * sin(alpha))
    worldNode.transform = SCNMatrix4(
      m11: 1, m12: 0, m13: 0, m14: 0,
      m21: 0, m22: 1, m23: 0, m24: 0,
      m31: szx, m32: szy, m33: 1, m34: 0,
      m41: 0, m42: 0, m43: 0, m44: 1)
    scene.rootNode.addChildNode(worldNode)
    scene.rootNode.addChildNode(backdropNode)

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

  /// Loads (if not already, or if the level's backdrop changed) `spriteID`'s PNG as
  /// `backdropNode`'s plane texture, sized to the image's own pixel dimensions - matching
  /// `RenderList.swift`'s 2D backdrop command, which draws that same PNG at its native size
  /// rather than scaling it to the level bounds.
  private func loadBackdropIfNeeded(spriteID: Int32) {
    guard spriteID != loadedBackdropSpriteID else { return }
    loadedBackdropSpriteID = spriteID
    backdropNode.geometry = nil
    guard spriteID >= 0, spriteID < spriteNameTable.count else { return }
    let staticName = spriteNameTable[Int(spriteID)]
    let name = staticName.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
    guard !name.isEmpty else { return }
    let directories = [backgroundsDirectory, backgroundsUndercoverDirectory, spritesDirectory]
    var image: Any?
    for directory in directories {
      let path = directory.appendingPathComponent("\(name).png").path
      guard FileManager.default.fileExists(atPath: path) else { continue }
      #if canImport(UIKit)
      image = UIImage(contentsOfFile: path)
      #else
      image = NSImage(contentsOfFile: path)
      #endif
      if image != nil { break }
    }
    guard let loadedImage = image else { return }
    #if canImport(UIKit)
    let size = (loadedImage as! UIImage).size
    #else
    let size = (loadedImage as! NSImage).size
    #endif
    guard size.width > 0, size.height > 0 else { return }
    let plane = SCNPlane(width: size.width, height: size.height)
    let material = SCNMaterial()
    material.diffuse.contents = loadedImage
    material.lightingModel = .constant
    material.isDoubleSided = true
    plane.materials = [material]
    backdropNode.geometry = plane
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
        if e.type == .junkbot { Self.applyWalkCycle(to: existing, animationFrame: e.animationFrame) }
        continue
      }
      guard let newNode = node(for: e) else { continue }
      newNode.position = Scene3DSpace.center(of: e)
      if e.type != .brick {
        newNode.eulerAngles.y = e.facing == 1 ? .pi / 2 : -.pi / 2
      }
      if e.type == .junkbot { Self.applyWalkCycle(to: newNode, animationFrame: e.animationFrame) }
      worldNode.addChildNode(newNode)
      nodesByEntityID[e.id] = newNode
    }

    for (id, node) in nodesByEntityID where !seenIDs.contains(id) {
      node.removeFromParentNode()
      nodesByEntityID.removeValue(forKey: id)
    }
  }

  /// Frames the camera straight-on (looking down -z at the z=0 plane every entity's *unsheared*
  /// position sits on - the angled look comes from `worldNode`'s oblique-shear transform in
  /// `init`, not from tilting the camera), tracking the *same* scrolling camera the 2D path uses
  /// (`cameraCenterX`/`cameraCenterY`/`cameraScale`, `windowWidth`/`windowHeight` - see
  /// `GameShell.swift`) rather than fitting the whole level's bounds into view: the level can be
  /// larger than one screen (the 2D camera pans/follows Junkbot within it, per `updateCamera()`),
  /// so framing the *entire* level here instead would show a completely different, non-scrolling
  /// crop than the 2D path's at any given moment - which is what made entities appear to have
  /// "jumped" to the wrong place even though each position was individually correct. `windowWidth`/
  /// `windowHeight` (divided by `cameraScale`) is the world-unit span the 2D logical canvas shows
  /// before `SKView`'s `.aspectFit` scales that canvas onto the real window - `orthographicScale`
  /// is fit to the *live* `SCNView` aspect ratio the same way, so the two paths still agree on
  /// what the limiting axis/letterboxing is even if the real window's aspect ratio doesn't match
  /// the logical canvas's. Call every tick while the 3D scene is active (like `sync(entities:)`),
  /// not just on level load - the 2D camera moves continuously as Junkbot walks.
  func syncCamera() {
    let canvasW = CGFloat(windowWidth) / CGFloat(cameraScale)
    let canvasH = CGFloat(windowHeight) / CGFloat(cameraScale)
    let viewBounds = scnView?.bounds ?? CGRect(x: 0, y: 0, width: canvasW, height: canvasH)
    let viewAspect = viewBounds.height > 0 ? viewBounds.width / viewBounds.height : 1
    let canvasAspect = canvasH > 0 ? canvasW / canvasH : 1
    let halfHeight: CGFloat =
      viewAspect >= canvasAspect ? canvasH / 2 : (canvasW / 2) / viewAspect
    cameraNode.camera?.orthographicScale = Double(halfHeight)

    let cx = CGFloat(cameraCenterX)
    let cy = -CGFloat(cameraCenterY)
    cameraNode.position = SCNVector3(cx, cy, 1000)
    cameraNode.look(at: SCNVector3(cx, cy, 0))
  }

  /// (Re)loads and positions the level backdrop - call once per level load (`reset()`'s
  /// companion), not every tick: unlike the camera, the backdrop's own world position never
  /// moves, only the (separately-tracked) camera pans over it.
  func loadBackdrop(spriteID: Int32) {
    loadBackdropIfNeeded(spriteID: spriteID)
    guard let plane = backdropNode.geometry as? SCNPlane else { return }
    // Matches `RenderList.swift`'s `.sprite(backdropSpriteID, x: -6, y: -25)`: that command draws
    // the image's top-left corner at world `(-6, -25)`, so its center is offset by half its own
    // size from there. Flip y and push far behind the entities (very negative z) - see
    // `backdropNode`'s doc comment for why this stays unsheared and still lines up.
    let bx = -6 + plane.width / 2
    let by = -(-25 + plane.height / 2)
    backdropNode.position = SCNVector3(bx, by, -500)
  }

  /// Walk-cycle length: matches `junkbotAnim_walk_r`/`_l`'s 10 keyframes (`JunkbotKeyframes.swift`)
  /// so `animationFrame % walkCycleLength` lines up with the same cadence the 2D sprite swap uses.
  private static let walkCycleLength: Int32 = 10
  /// Per-leg swing (radians) at the extremes of the stride - matches `tools/Junkbot3D`'s
  /// `LDrawModel.legSwingAmplitude`, which this mirrors.
  private static let legSwingAmplitude: Double = .pi / 6

  /// Swings `junkbot.scn`'s two independent leg nodes (`3816.dat`/`3817.dat`, baked by
  /// `tools/Junkbot3D --bake-all` from `junkbot.ldr`) opposite each other, driven by the entity's
  /// own `animationFrame` - mirrors `tools/Junkbot3D/Sources/Junkbot3D/LDrawModel.swift`'s
  /// `node(named:...)` leg-rig logic exactly, since the baked `.scn`'s node tree has the same
  /// shape (`node -> raw -> topModel -> [hips, rightLeg, leftLeg, body, head, lid]`) as what that
  /// tool builds and bakes. Node names aren't preserved through baking/`LDrawSceneBuilder`, so
  /// this relies on the same fixed authored subfile order as the offline tool does - see that
  /// file's comment for how the order was verified.
  private static func applyWalkCycle(to node: SCNNode, animationFrame: Int32) {
    guard let legs = node.childNodes.first?.childNodes.first?.childNodes, legs.count >= 3 else {
      return
    }
    // Divide by `walkCycleLength - 1`, not `walkCycleLength`, so the *last* sampled frame
    // (walkCycleLength - 1) lands on a full 2*pi - back at sin = 0, legs neutral/studs-aligned -
    // same as frame 0, instead of stopping mid-swing right before the loop wraps.
    let phase =
      2 * Double.pi * Double(animationFrame % walkCycleLength) / Double(walkCycleLength - 1)
    let swing = sin(phase) * legSwingAmplitude
    legs[1].eulerAngles.x = CGFloat(swing)
    legs[2].eulerAngles.x = CGFloat(-swing)
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
