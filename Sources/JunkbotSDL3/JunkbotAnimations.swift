import Foundation
import JunkbotCore

/// One keyframe of a Junkbot animation, decoded from `junkbot-animations.json` (repo root) - the
/// same per-frame keyframe/pixel-offset table `src/game.js`'s `drawJunkbot` reads as
/// `resources.junkbotAnimations`. Only walk cycles (`walk_l`/`walk_r`/`shield_walk_l`/
/// `shield_walk_r`) are present in that file; every other Junkbot animation state (dying, eating a
/// bin, putting on a shield, etc.) falls back to a plain `minifig_<name>_<frame>` naming scheme
/// with no offset, matching JS's own fallback in `drawJunkbot` for animation names it has no
/// keyframe table for.
struct JunkbotKeyframe: Decodable {
  struct Offset: Decodable {
    var x: Int32
    var y: Int32
  }
  var sprite: String
  var offset: Offset
  /// Marks a footstep frame in the original game (for a footstep sound cue); unused here - this
  /// native target has no audio yet.
  var emit_event: Bool?
}

let junkbotAnimations: [String: [JunkbotKeyframe]] = {
  let url = repoRoot.appendingPathComponent("junkbot-animations.json")
  guard let data = try? Data(contentsOf: url),
    let decoded = try? JSONDecoder().decode([String: [JunkbotKeyframe]].self, from: data)
  else { return [:] }
  return decoded
}()

/// Resolves Junkbot's current animation state (mirroring `drawJunkbot` in `src/game.js`) to a
/// concrete sprite name and pixel offset for this tick. Kept separate from `spriteName(for:)`/
/// `spriteDrawPosition(for:textureWidth:textureHeight:)` (used for every other entity type)
/// since Junkbot is the only type with a real per-keyframe offset table rather than one fixed
/// offset per type.
func junkbotFrame(for e: Entity) -> (spriteName: String, offsetX: Int32, offsetY: Int32) {
  var animName: String
  var animLength = 10
  if e.dead {
    return ("minifig_dead", 0, 0)
  } else if e.dyingFromWater {
    animName = "water_die"
  } else if e.dying {
    animName = "die"
  } else if e.collectingBin {
    animName = e.armored ? "shield_eat" : "eat_start"
    animLength = 17
  } else if e.gettingShield {
    animName = "shield_on_\(e.facing == 1 ? "r" : "l")"
    animLength = 11
  } else {
    animName = "walk_\(e.facing == 1 ? "r" : "l")"
  }
  if e.armored && (!e.losingShield || e.animationFrame % 4 < 2) {
    if animName == "eat_start" {
      animName = "shield_eat"
    } else if !animName.contains("shield") {
      animName = "shield_\(animName)"
    }
  }

  if let keyframes = junkbotAnimations[animName], !keyframes.isEmpty {
    let frame = keyframes[Int(e.animationFrame) % keyframes.count]
    return (frame.sprite, frame.offset.x, frame.offset.y)
  }
  let frame = 1 + Int(e.animationFrame) % animLength
  return ("minifig_\(animName)_\(frame)", 0, 0)
}
