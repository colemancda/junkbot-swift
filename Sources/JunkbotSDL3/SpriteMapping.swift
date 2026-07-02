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
/// Simplifications versus the JS renderer (acceptable for a first native pass): no fan-wind/
/// laser-beam/teleport-effect particle overlays, and scaredy bins always use their resting sprite
/// rather than their flee animation. Junkbot itself is handled separately by `junkbotFrame(for:)`
/// (`JunkbotAnimations.swift`), which does reproduce JS's real per-keyframe offset table. Returns
/// `nil` for entity types/states with no discovered sprite convention (currently: none — every
/// `EntityType` maps to something), in which case the caller falls back to a flat colored rectangle.
func spriteName(for e: Entity) -> String? {
  switch e.type {
  case .brick:
    let colorName = brickColorNames.indices.contains(Int(e.colorIndex)) ? brickColorNames[Int(e.colorIndex)] : "gray"
    let colorPart = colorName == "gray" ? "immobile" : colorName
    return "brick_\(colorPart)_\(e.widthInStuds)"

  case .junkbot:
    // Handled by junkbotFrame(for:) instead - see render()'s special case.
    return nil

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
    // Ping-pong 0,1,2,3,2,1,0,... over an 8-tick period (matches JS's drawFire exactly).
    let m8 = Int(e.animationFrame) % 8
    let frameIndex = e.on ? (m8 < 4 ? m8 : 4 - (Int(e.animationFrame) % 4)) : 0
    return "haz_slickFire_\(e.on ? "on" : "off")_\(1 + frameIndex)"

  case .fan:
    let frameIndex = e.on ? Int(e.animationFrame) % 4 : 0
    return "haz_slickFan_\(e.on ? "on" : "off")_\(1 + frameIndex)"

  case .switch:
    return "haz_slickSwitch_\(e.on ? "on" : "off")_1"

  case .pipe:
    // `timer` counts down from MAX_DRIP_PERIOD; JS's drawPipe treats <=6 (and >-1) as "wet",
    // showing a wet frame that counts down to 1 as the timer approaches 0.
    let wet = e.timer <= 6 && e.timer > -1
    let frameIndex = wet ? 6 - Int(e.timer) : 0
    return "haz_slickPipe_\(wet ? "wet" : "dry")_\(1 + frameIndex)"

  case .shield:
    if e.fixed {
      return "HAZ_SLICKSHIELD_\(e.used ? "OFF" : "ON")"
    }
    return "BRICK_SLICKSHIELD_\(e.used ? "OFF" : "ON")"

  case .teleport:
    if e.timer > 30 { return "haz_slickTeleport_active_\(1 + Int(e.timer) % 2)" }
    return "haz_slickTeleport_\(e.timer == 0 && !e.blocked ? "on" : "off")_1"

  case .laser:
    return "haz_slickLaser_\(e.facing == 1 ? "L" : "R")_ON_1"

  case .jump:
    let animName = e.active ? "active" : "dormant"
    let animLength = e.active ? 5 : 1
    let frameIndex = Int(e.animationFrame) % animLength
    return "\(e.fixed ? "haz" : "brick")_slickJump_\(animName)_\(1 + frameIndex)"

  case .droplet:
    let frameIndex = e.splashing ? Int(e.animationFrame) : 0
    return "drip_\(e.splashing ? "splashing" : "falling")_\(1 + frameIndex)"

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
  case .laser: return (x, Float(e.y) + Float(e.height) - 1 - textureHeight)
  default: return (x, bottomAligned)
  }
}
