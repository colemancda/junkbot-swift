import JunkbotCore

/// Matches JS's `brickColorNames` (`Sources/JunkbotCore/LevelSerialize.swift`), duplicated here
/// since that array isn't `public`. Order is load-bearing: it's `Entity.colorIndex`'s index space.
private let brickColorNames = ["white", "red", "green", "blue", "yellow", "gray"]

/// Maps a live `Entity` to the base filename (no directory, no `.png`) of the sprite that
/// represents its current visual state, mirroring `src/game.js`'s `draw*` functions (e.g.
/// `drawBrick`/`drawJunkbot`/`drawGearbot`) closely enough to reuse the exact same source PNGs
/// (`images/sprites/`, falling back to `images/sprites/Undercover Exclusive/` for the handful of
/// types only present there — crates, teleports, non-fixed shields, lasers).
///
/// Simplifications versus the JS renderer (acceptable for a first native pass): no per-keyframe
/// pixel offsets for Junkbot's animations (JS's `resources.junkbotAnimations` table isn't
/// reproduced here), no fan-wind/laser-beam/teleport-effect particle overlays, and scaredy bins
/// always use their resting sprite rather than their flee animation. Returns `nil` for entity
/// types/states with no discovered sprite convention (currently: none — every `EntityType` maps
/// to something), in which case the caller falls back to a flat colored rectangle.
func spriteName(for e: Entity) -> String? {
  switch e.type {
  case .brick:
    let colorName = brickColorNames.indices.contains(Int(e.colorIndex)) ? brickColorNames[Int(e.colorIndex)] : "gray"
    let colorPart = colorName == "gray" ? "immobile" : colorName
    return "brick_\(colorPart)_\(e.widthInStuds)"

  case .junkbot:
    if e.dead { return "minifig_dead" }
    if e.dyingFromWater { return "minifig_water_die_1" }
    if e.dying { return "minifig_die_1" }
    let facingLetter = e.facing == 1 ? "r" : "l"
    if e.collectingBin { return e.armored ? "minifig_shield_eat_1" : "minifig_eat_start_1" }
    if e.gettingShield { return "minifig_shield_on_\(facingLetter)_1" }
    let frame = 1 + Int(e.animationFrame) % 10
    return e.armored ? "minifig_shield_walk_\(facingLetter)_\(frame)" : "minifig_walk_\(facingLetter)_\(frame)"

  case .gearbot:
    let frame = 1 + Int(e.animationFrame) % 2
    return "gearbot_walk_\(e.facing == 1 ? "r" : "l")_\(frame)"

  case .climbbot:
    let direction: String
    if e.facingY == -1 {
      direction = "u"
    } else if e.facingY == 1 {
      direction = "d"
    } else {
      direction = e.facing == 1 ? "r" : "l"
    }
    let frame = 1 + Int(e.animationFrame) % 6
    return "climbbot_walk_\(direction)_\(frame)"

  case .flybot:
    return "flybot_\(1 + Int(e.animationFrame) % 2)"

  case .eyebot:
    let frame = 1 + Int(e.animationFrame) % 2
    return "eyebot_\(e.activeTimer > 0 ? "active_" : "")\(frame)"

  case .bin:
    return "bin"

  case .crate:
    return "HAZ_SLICKCRATE"

  case .fire:
    return "haz_slickFire_\(e.on ? "on" : "off")_1"

  case .fan:
    return "haz_slickFan_\(e.on ? "on" : "off")_1"

  case .switch:
    return "haz_slickSwitch_\(e.on ? "on" : "off")_1"

  case .pipe:
    return "haz_slickPipe_dry_1"

  case .shield:
    if e.fixed {
      return "HAZ_SLICKSHIELD_\(e.used ? "OFF" : "ON")"
    }
    return "BRICK_SLICKSHIELD_\(e.used ? "OFF" : "ON")"

  case .teleport:
    if e.timer > 30 { return "haz_slickTeleport_active_1" }
    return "haz_slickTeleport_\(e.timer == 0 && !e.blocked ? "on" : "off")_1"

  case .laser:
    return "haz_slickLaser_\(e.facing == 1 ? "L" : "R")_ON_1"

  case .jump:
    let animName = e.active ? "active" : "dormant"
    return "\(e.fixed ? "haz" : "brick")_slickJump_\(animName)_1"

  case .droplet:
    return "drip_\(e.splashing ? "splashing" : "falling")_1"

  case .levelBounds, .unknown:
    return nil
  }
}

/// World-space position to draw a `textureWidth`x`textureHeight` sprite for `entity`, mirroring
/// each `draw*` function's specific offset in `src/game.js` (most bottom-align the sprite to the
/// entity's bounding box with a small fixed nudge; a couple, like `drawPipe`/`drawClimbbot`, are
/// top-aligned instead). Falls back to simple bottom-left alignment for anything not specifically
/// called out below.
func spriteDrawPosition(for e: Entity, textureWidth: Float, textureHeight: Float) -> (x: Float, y: Float) {
  let x = Float(e.x)
  let bottomAligned = Float(e.y) + Float(e.height) - textureHeight
  switch e.type {
  case .bin: return (x + 4, bottomAligned - 5)
  case .crate: return (x, bottomAligned - 1)
  case .fire, .fan: return (x + 1, bottomAligned - 4)
  case .jump, .shield, .teleport, .switch, .gearbot, .flybot, .eyebot: return (x, bottomAligned - 1)
  case .pipe: return (x + 11, Float(e.y) - 12)
  case .droplet: return (x + 15, Float(e.y))
  case .climbbot: return (x, Float(e.y) - 6)
  case .junkbot, .laser: return (x, Float(e.y) + Float(e.height) - 1 - textureHeight)
  default: return (x, bottomAligned)
  }
}
