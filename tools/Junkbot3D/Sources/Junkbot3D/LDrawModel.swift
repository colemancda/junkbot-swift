import Foundation
import SceneKit

/// Loads this tool's authored `.ldr` models (`tools/Junkbot3D/Models/*.ldr` - real official LEGO
/// parts assembled to represent a game entity, see `LDrawLoader.swift`) as bottom-center-anchored,
/// game-scaled nodes, matching the anchor convention every procedural mesh in `CharacterGeometry`
/// uses (root position = center of the entity's bounding box; content spans from `-height/2` at
/// the bottom upward), so callers can position the result identically via `Space.center(of:)`.
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

  /// `name` is the file's base name under `tools/Junkbot3D/Models` (e.g. `"junkbot"` for
  /// `junkbot.ldr`). Returns `nil` if the model file is missing or fails to parse - callers
  /// should fall back to a procedural mesh in that case.
  static func node(
    named name: String, entityWidth: CGFloat, entityHeight: CGFloat, repoRoot: URL, ldrawRoot: URL,
    colorTable: LDrawColorTable
  ) -> SCNNode? {
    if let cached = cache[name] { return cached.clone() }

    let modelURL = repoRoot.appendingPathComponent("tools/Junkbot3D/Models")
      .appendingPathComponent("\(name).ldr")
    guard
      let raw = LDrawLoader.loadModel(
        fileURL: modelURL, colorCode: 16, ldrawRoot: ldrawRoot, colorTable: colorTable)
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

    cache[name] = wrapper
    return wrapper.clone()
  }
}
