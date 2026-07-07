import Foundation
import JunkbotCore
import SceneKit

/// Turns a loaded level's entities into an `SCNScene` — the offline-preview equivalent of
/// `RenderList.buildRenderFrame`, but building a 3D node tree instead of a 2D command list.
@MainActor
enum SceneBuilder {
  static func makeScene(
    entities: [Entity], bounds: LevelBounds?, repoRoot: URL, ldrawRoot: URL,
    colorTable: LDrawColorTable
  ) -> SCNScene {
    let scene = SCNScene()
    let root = scene.rootNode

    for e in entities {
      guard
        let node = node(for: e, repoRoot: repoRoot, ldrawRoot: ldrawRoot, colorTable: colorTable)
      else { continue }
      node.position = Space.center(of: e)
      root.addChildNode(node)
    }

    let ambient = SCNLight()
    ambient.type = .ambient
    ambient.color = Palette.rgb(0xB0, 0xB0, 0xB8)
    let ambientNode = SCNNode()
    ambientNode.light = ambient
    root.addChildNode(ambientNode)

    let sun = SCNLight()
    sun.type = .directional
    sun.color = Palette.rgb(0xFF, 0xFF, 0xF0)
    sun.castsShadow = false  // PS1/DS-era: no dynamic shadows, keeps the flat low-poly look.
    let sunNode = SCNNode()
    sunNode.light = sun
    sunNode.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
    root.addChildNode(sunNode)

    return scene
  }

  /// Entity type -> authored `.ldr` model name (`tools/Junkbot3D/Models/<name>.ldr`), for every
  /// type with a real-parts model built (see the LDraw-loader work in `LDrawModel.swift`/
  /// `LDrawLoader.swift`). `.brick` isn't here: `BrickGeometry`'s procedural mesh already matches
  /// the game's exact stud grid and needs no model file. `.droplet` has no model yet.
  private static func ldrawModelName(for type: EntityType) -> String? {
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

  private static func node(
    for e: Entity, repoRoot: URL, ldrawRoot: URL, colorTable: LDrawColorTable
  ) -> SCNNode? {
    if e.type == .brick {
      return BrickGeometry.node(widthInStuds: e.widthInStuds, colorIndex: e.colorIndex)
    }
    if let modelName = ldrawModelName(for: e.type),
      let modelNode = LDrawModel.node(
        named: modelName, entityWidth: CGFloat(e.width), entityHeight: CGFloat(e.height),
        repoRoot: repoRoot, ldrawRoot: ldrawRoot, colorTable: colorTable)
    {
      // Same convention as `CharacterGeometry`'s procedural meshes: models are authored with
      // their front/back asymmetry (e.g. Junkbot's roof tile sitting toward local -z) as if
      // facing the camera, so rotate to face down the level's travel axis instead - see
      // `CharacterGeometry.junkbot`'s doc comment for why.
      modelNode.eulerAngles.y = e.facing == 1 ? .pi / 2 : -.pi / 2
      return modelNode
    }

    switch e.type {
    case .levelBounds, .unknown:
      return nil
    default:
      return CharacterGeometry.genericBox(e)
    }
  }

  /// An orthographic camera framing the level from a fixed iso-ish angle (matches the janitorial
  /// reference's approach in `three-stuff/3d-main.js`: orthographic keeps brick edges crisp/
  /// pixel-art-adjacent instead of perspective-distorting distant bricks). Positioned to frame
  /// `bounds` (or, absent bounds, the union of `entities`).
  static func framingCameraNode(entities: [Entity], bounds: LevelBounds?) -> SCNNode {
    let box = boundingBox(entities: entities, bounds: bounds)
    let cx = (box.minX + box.maxX) / 2
    let cy = -(box.minY + box.maxY) / 2  // flipped, matches Space.center
    let spanX = box.maxX - box.minX
    let spanY = box.maxY - box.minY

    let camera = SCNCamera()
    camera.usesOrthographicProjection = true
    // Half the taller of the two spans (in scene units), padded 12%, frames both axes since the
    // render target is roughly square; a real gameplay camera would instead track the viewport.
    camera.orthographicScale = Double(max(spanX, spanY)) * 0.56
    camera.zNear = 1
    camera.zFar = 4000

    let node = SCNNode()
    node.camera = camera
    // Classic isometric-ish LEGO-instructions angle: looking down and slightly to the side.
    let distance: CGFloat = 1500
    node.position = SCNVector3(cx + distance * 0.5, cy + distance * 0.42, distance * 0.75)
    node.look(at: SCNVector3(cx, cy, 0))
    return node
  }

  private static func boundingBox(entities: [Entity], bounds: LevelBounds?) -> (
    minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat
  ) {
    if let b = bounds {
      return (CGFloat(b.x), CGFloat(b.y), CGFloat(b.x + b.width), CGFloat(b.y + b.height))
    }
    var minX = CGFloat.greatestFiniteMagnitude
    var minY = CGFloat.greatestFiniteMagnitude
    var maxX = -CGFloat.greatestFiniteMagnitude
    var maxY = -CGFloat.greatestFiniteMagnitude
    for e in entities {
      minX = min(minX, CGFloat(e.x))
      minY = min(minY, CGFloat(e.y))
      maxX = max(maxX, CGFloat(e.x + e.width))
      maxY = max(maxY, CGFloat(e.y + e.height))
    }
    if minX > maxX { return (0, 0, 100, 100) }
    return (minX, minY, maxX, maxY)
  }
}
