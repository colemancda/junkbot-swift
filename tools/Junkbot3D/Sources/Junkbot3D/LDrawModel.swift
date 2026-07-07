import Foundation
import LegoDrawFile
import SceneKit

/// Loads this tool's authored `.ldr` models (`tools/Junkbot3D/Models/*.ldr` - real official LEGO
/// parts assembled to represent a game entity, built via `LDrawSupport`/swift-lego-draw) as
/// bottom-center-anchored, game-scaled nodes, matching the anchor convention every procedural
/// mesh in `CharacterGeometry` uses (root position = center of the entity's bounding box; content
/// spans from `-height/2` at the bottom upward), so callers can position the result identically
/// via `Space.center(of:)`.
@MainActor
enum LDrawModel {
  /// LDraw's own unit (1 stud = 20 LDU, 1 brick row = 24 LDU) is a fixed 0.75x of this game's grid
  /// (1 stud = `CELL_W` = 15, 1 row = `CELL_H` = 18) - not a coincidence: LDraw's stud-width:
  /// brick-height ratio is LEGO's real one, which the game's own sprite grid also preserves.
  static let scale: CGFloat = 0.75

  /// Cache key is the model name alone (not width/height): every entity of a given type shares
  /// the same fixed size (set once in `EntityFactory`), so baking one instance's anchor offset
  /// into the cached template is safe to reuse for every other instance of that type.
  private static var cache: [String: SCNNode] = [:]

  /// Walk-cycle length: matches `junkbotAnim_walk_r`/`_l`'s 10 keyframes (`JunkbotKeyframes.swift`)
  /// so `animationFrame % walkCycleLength` lines up with the same cadence the 2D sprite swap uses.
  static let walkCycleLength: Int32 = 10
  /// Per-leg swing (radians) at the extremes of the stride.
  private static let legSwingAmplitude: Double = .pi / 6

  /// `name` is the file's base name under `tools/Junkbot3D/Models` (e.g. `"junkbot"` for
  /// `junkbot.ldr`). Returns `nil` if the model file is missing or fails to parse - callers
  /// should fall back to a procedural mesh in that case. `animationFrame` drives the walk-cycle
  /// leg swing when the model has rigged legs (currently only `"junkbot"`); ignored otherwise.
  static func node(
    named name: String, entityWidth: CGFloat, entityHeight: CGFloat, repoRoot: URL, ldrawRoot: URL,
    colorTable: LDrawColorTable, animationFrame: Int32 = 0
  ) -> SCNNode? {
    let instance: SCNNode
    if let cached = cache[name] {
      instance = cached.clone()
    } else {
      guard let built = buildInstance(
        named: name, entityWidth: entityWidth, entityHeight: entityHeight, repoRoot: repoRoot,
        ldrawRoot: ldrawRoot, colorTable: colorTable)
      else { return nil }
      cache[name] = built
      instance = built.clone()
    }

    // `junkbot.ldr` places its right/left leg subfiles (`3816.dat`/`3817.dat`) with the leg's own
    // origin already at the hip pivot (see the model's own comment), so rotating each leg node
    // about local X in place swings it like a hinge - no extra pivot offset needed. Legs swing
    // oppositely (out of phase by pi), matching a real gait.
    //
    // `LDrawSceneBuilder`'s parts carry no `SCNNode.name` (an `.dat` part file's own `0 Name:`
    // line isn't threaded into the resolved model's `name` unless it's an MPD embedded section),
    // so leg nodes can't be found by name. Instead rely on structural position: `instance`'s tree
    // is `instance -> raw (LDrawSupport's 180°-about-X wrapper) -> topModel -> [hips, rightLeg,
    // leftLeg, body, head, lid]`, in `junkbot.ldr`'s authored subfile order (verified by dumping
    // the tree and matching each node's `position` against the `.ldr`'s own placement lines).
    let legParent = instance.childNodes.first?.childNodes.first
    if let legs = legParent?.childNodes, legs.count >= 3 {
      let rightLeg = legs[1]
      let leftLeg = legs[2]
      // Divide by `walkCycleLength - 1`, not `walkCycleLength`, so the *last* sampled frame
      // (walkCycleLength - 1) lands on a full 2*pi - back at sin = 0, legs neutral/studs-aligned -
      // same as frame 0, instead of stopping mid-swing right before the loop wraps.
      let phase =
        2 * Double.pi * Double(animationFrame % walkCycleLength) / Double(walkCycleLength - 1)
      let swing = sin(phase) * legSwingAmplitude
      rightLeg.eulerAngles.x = CGFloat(swing)
      leftLeg.eulerAngles.x = CGFloat(-swing)
    }

    return instance
  }

  private static func buildInstance(
    named name: String, entityWidth: CGFloat, entityHeight: CGFloat, repoRoot: URL, ldrawRoot: URL,
    colorTable: LDrawColorTable
  ) -> SCNNode? {
    let modelsDirectory = repoRoot.appendingPathComponent("tools/Junkbot3D/Models")
    let modelURL = modelsDirectory.appendingPathComponent("\(name).ldr")
    guard let text = try? String(contentsOf: modelURL, encoding: .utf8),
      let raw = LDrawSupport.buildNode(
        text: text, extraSearchDirectory: modelsDirectory, colorCode: 16, ldrawRoot: ldrawRoot,
        colorTable: colorTable)
    else { return nil }

    let wrapper = SCNNode()
    raw.scale = SCNVector3(scale, scale, scale)
    wrapper.addChildNode(raw)

    // Anchor bottom-center: shift so the model's own bottom sits at local y = -entityHeight/2 and
    // its horizontal center sits at local x = 0 (z is left alone - a model's own front/back
    // placement, e.g. Junkbot's roof tile sitting toward the back, is intentional).
    let (min, max) = wrapper.boundingBox
    let centerX = (min.x + max.x) / 2
    raw.position = SCNVector3(
      raw.position.x - centerX, raw.position.y - min.y - entityHeight / 2, raw.position.z)

    return wrapper
  }
}
