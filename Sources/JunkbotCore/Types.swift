/// Grid cell width in world-space pixels (matches JS: `snapX = 15`).
public let CELL_W: Int32 = 15
/// Grid cell height in world-space pixels (matches JS: `snapY = 18`).
public let CELL_H: Int32 = 18

/// Ticks a teleport pad stays unusable after teleporting an entity through it.
let TELEPORT_COOLDOWN: Int32 = 50
/// Number of ticks, at the start of `TELEPORT_COOLDOWN`, during which the teleport visual
/// effect is emitted.
let TELEPORT_EFFECT_PERIOD: Int32 = 20
/// Upper bound (exclusive) on the random tick interval between a pipe's water drips.
let MAX_DRIP_PERIOD: Int32 = 50
/// Lower bound (inclusive) on the random tick interval between a pipe's water drips.
let MIN_DRIP_PERIOD: Int32 = 20

/// The kind of game object an `Entity` represents. Determines which of `Entity`'s otherwise-unused
/// fields are meaningful (see `Entity`) and which `simulate*` function in `Simulation.swift`
/// handles it each tick.
public enum EntityType: UInt8 {
  /// A static or draggable brick; `fixed` bricks (gray) can't be picked up.
  case brick = 0
  /// The player-controlled robot. There is normally exactly one per level.
  case junkbot = 1
  /// An enemy that walks back and forth, turning around at walls/edges and hurting Junkbot on contact.
  case gearbot = 2
  /// An enemy that climbs walls/ceilings, hurting Junkbot on contact.
  case climbbot = 3
  /// An enemy that flies in a straight line, turning around at obstacles.
  case flybot = 4
  /// A stationary enemy that tracks Junkbot with a raycast and fires when aligned.
  case eyebot = 5
  /// A collectible trash bin; the level is won once every bin has been collected.
  case bin = 6
  /// A pushable box.
  case crate = 7
  /// A fire hazard; hurts Junkbot when `on`.
  case fire = 8
  /// A hazard tile that, when `on`, pushes floating entities upward (see `WindEffect`).
  case fan = 9
  /// A toggle that flips the `on` state of every other entity sharing its `switchID`.
  case `switch` = 10
  /// Periodically spawns a falling `droplet`.
  case pipe = 11
  /// A pickup that grants Junkbot temporary armor (see `Entity.armored`/`losingShield`).
  case shield = 12
  /// One end of a linked teleporter pair (matched by `Entity.teleportID`).
  case teleport = 13
  /// A hazard that fires a beam (see `LaserBeam`); hurts Junkbot when `on` and it enters the beam.
  case laser = 14
  /// A brick that launches Junkbot upward when stepped on (unless `active`, i.e. on cooldown).
  case jump = 15
  /// A falling water droplet spawned by a `pipe`; hurts Junkbot on contact.
  case droplet = 16
  /// Synthetic entity type returned by collision queries to represent the level's boundary walls;
  /// never actually stored in `GameEngine.entities`.
  case levelBounds = 17
  /// Placeholder for an unrecognized/unmapped type name (e.g. from malformed level data).
  case unknown = 255
}

/// Sound effect indices passed to `GameEngine.onPlaySound`. Must stay in sync with the JS-side
/// sound name table (`harness.js`) that maps these indices back to actual audio files.
enum SoundID: Int32 {
  case turn = 0
  case blockPickUp = 1
  case blockDrop = 2
  case blockClick = 3
  case fall = 4
  case headBonk = 5
  case collectBin = 6
  case collectBin2 = 7
  case switchClick = 8
  case switchOn = 9
  case switchOff = 10
  case deathByFire = 11
  case deathByWater = 12
  case deathByLaser = 13
  case deathByBot = 14
  case getShield = 15
  case getPowerup = 16
  case losePowerup = 17
  case teleportSound = 18
  case ohYeah = 19
  case ouch = 20
  case uhoh = 21
  case jump = 22
  case fan = 23
  case drip0 = 24
  case drip1 = 25
  case drip2 = 26
  case undo = 27
}

/// The playable level's boundary rectangle, in world-space pixels. Entities that would cross
/// this boundary collide with it as if it were a solid wall (see `rectangleLevelBoundsCollision`
/// in `Collision.swift`).
public struct LevelBounds {
  public var x: Int32
  public var y: Int32
  public var width: Int32
  public var height: Int32

  public init(x: Int32, y: Int32, width: Int32, height: Int32) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
}

/// The per-column updraft profile cast by one active `fan` entity for the current tick, used to
/// render the wind effect and to make overlapping entities `floating` (see `simulateFansAndLasers`
/// in `Simulation.swift`). `extents` is a fixed-size inline tuple (avoiding a heap-allocated array)
/// holding up to 8 columns' worth of updraft height, one entry per grid column spanned by the fan.
public struct WindEffect {
  /// Index into `GameEngine.entities` of the fan that cast this effect.
  public var fanEntityIndex: Int
  /// The number of columns actually populated in `extents` (0...8).
  public var numExtents: Int
  var extents: (Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32)

  init(fanEntityIndex: Int) {
    self.fanEntityIndex = fanEntityIndex
    self.numExtents = 0
    self.extents = (0, 0, 0, 0, 0, 0, 0, 0)
  }

  /// Appends an updraft height (in grid cells) for the next column; ignored once 8 have been added.
  mutating func addExtent(_ v: Int32) {
    guard numExtents < 8 else { return }
    switch numExtents {
    case 0: extents.0 = v
    case 1: extents.1 = v
    case 2: extents.2 = v
    case 3: extents.3 = v
    case 4: extents.4 = v
    case 5: extents.5 = v
    case 6: extents.6 = v
    default: extents.7 = v
    }
    numExtents += 1
  }

  /// The updraft height (in grid cells) for column `i`; out-of-range indices clamp to the last slot.
  public func extent(at i: Int) -> Int32 {
    switch i {
    case 0: return extents.0
    case 1: return extents.1
    case 2: return extents.2
    case 3: return extents.3
    case 4: return extents.4
    case 5: return extents.5
    case 6: return extents.6
    default: return extents.7
    }
  }
}

/// The current beam cast by one active `laser` entity for the current tick, used to render the
/// beam and to know what it's currently hitting (see `simulateFansAndLasers` in `Simulation.swift`).
public struct LaserBeam {
  /// Index into `GameEngine.entities` of the laser that cast this beam.
  public var laserEntityIndex: Int
  /// Beam length in grid cells, from the laser to whatever it hit (or its max range if nothing).
  public var extent: Int32
  /// Index into `GameEngine.entities` of the entity the beam is currently hitting, or `-1` if none.
  public var hitEntityIndex: Int
}

/// The result of a grid-stepped `raycast` (see `Collision.swift`): how far the ray traveled before
/// hitting something, and what it hit (if anything).
public struct RaycastHit {
  /// Number of grid steps traveled before stopping.
  public var steps: Int32
  /// The entity that was hit, or `nil` if the ray reached its maximum range unobstructed.
  public var entity: Entity?
  /// Index into `GameEngine.entities` of `entity`, or `-1` if nothing was hit.
  public var entityIndex: Int
}

/// One frame of the teleport-in-progress visual effect, emitted while a teleport pad is on
/// cooldown just after use (see `simulateTeleport` in `Simulation.swift`).
public struct TeleportEffect {
  public var x: Int32
  public var y: Int32
  /// Which frame of the effect's animation to draw.
  public var frameIndex: Int32
}

/// A single game object. This is a "wide" struct shared by every `EntityType` — most fields are
/// meaningful for only one or two types and left at their default for everything else (e.g.
/// `switchID` only matters for `.switch`/`.fire`/`.fan`/`.laser`; `armored`/`losingShield` only for
/// `.junkbot`). This trades memory density for a single uniform representation that's cheap to
/// store in one contiguous `GameEngine.entities` array and pass across the JS bridge without a
/// large union/enum-with-payload.
public struct Entity {
  /// Unique, level-scoped identifier, assigned once at creation and stable across ticks (unlike
  /// its index into `GameEngine.entities`, which can change as entities are added/removed/sorted).
  public var id: Int32
  public var type: EntityType
  /// World-space position of the entity's top-left corner, in pixels (grid-aligned to `CELL_W`).
  public var x: Int32
  /// World-space position of the entity's top-left corner, in pixels (grid-aligned to `CELL_H`).
  public var y: Int32
  public var width: Int32
  public var height: Int32

  /// Whether this entity is currently being dragged by the player (excluded from gravity/collision
  /// as a mover, though still collidable as an obstacle).
  public var grabbed: Bool
  /// Whether this entity is immovable (gray bricks, and most hazards/fixtures).
  public var fixed: Bool
  /// Whether a `fan`'s updraft is currently holding this entity aloft (bricks) or letting Junkbot
  /// float upward (junkbot); recomputed every tick by `simulateFansAndLasers`.
  public var floating: Bool
  /// Whether this entity was `floating` on the *previous* tick, used to detect the fan-pickup edge
  /// (e.g. to only play the "caught by fan" sound once).
  public var wasFloating: Bool
  /// Marks a collected bin (or other entity) for removal at the end of the current tick, rather
  /// than mutating `GameEngine.entities` mid-iteration.
  public var removeBeforeRender: Bool

  /// Horizontal facing/movement direction: `1` (right) or `-1` (left).
  public var facing: Int32
  /// Vertical facing/movement direction for climbbot/eyebot: `1` (down), `-1` (up), or `0`.
  public var facingY: Int32
  /// Per-entity animation frame counter; also double-duty as a simulation timer for several types
  /// (e.g. gates junkbot's walk cadence, gearbot/climbbot/flybot's move cadence).
  public var animationFrame: Int32

  /// Brick width in studs (i.e. `width / CELL_W`); only meaningful for `.brick`.
  public var widthInStuds: Int32
  /// Index into the level's color palette; only meaningful for `.brick`.
  public var colorIndex: Int32

  /// Whether Junkbot currently has shield protection (survives one hit instead of dying); only
  /// meaningful for `.junkbot`.
  public var armored: Bool
  /// Whether Junkbot's shield is actively counting down to expiration; only meaningful for `.junkbot`.
  public var losingShield: Bool
  /// Ticks elapsed since `losingShield` became true; the shield expires once this exceeds the
  /// threshold checked in `simulateJunkbot`. Only meaningful for `.junkbot`.
  public var losingShieldTime: Int32
  /// Whether Junkbot is currently playing the "picking up a shield" animation; only meaningful
  /// for `.junkbot`.
  public var gettingShield: Bool
  /// Whether Junkbot is currently playing the death animation (before `dead` becomes true); only
  /// meaningful for `.junkbot`.
  public var dying: Bool
  /// Whether the current death was caused by water (selects the drowning vs. other death
  /// animation/sound); only meaningful for `.junkbot`.
  public var dyingFromWater: Bool
  /// Whether Junkbot has finished dying; once true, the level is lost. Only meaningful for `.junkbot`.
  public var dead: Bool
  /// Whether Junkbot is currently playing the "collecting a bin" animation; only meaningful for
  /// `.junkbot`.
  public var collectingBin: Bool
  /// Whether something above Junkbot's head is currently blocking upward movement; only
  /// meaningful for `.junkbot`.
  public var headLoaded: Bool
  /// Horizontal ballistic velocity while airborne (jumping/falling); only meaningful for `.junkbot`.
  public var momentumX: Int32
  /// Vertical ballistic velocity while airborne (jumping/falling); only meaningful for `.junkbot`.
  public var momentumY: Int32

  /// Whether this bin runs from Junkbot instead of sitting still; only meaningful for `.bin`.
  public var scaredy: Bool

  /// Whether this hazard/switch is currently active; only meaningful for `.fire`/`.fan`/`.laser`/`.switch`.
  public var on: Bool
  /// Whether this shield has already been picked up (so it won't be collected again); only
  /// meaningful for `.shield`.
  public var used: Bool
  /// Groups this entity with every other entity sharing the same `switchID` for the purposes of a
  /// `.switch`'s toggle; `-1` means unlinked. Only meaningful for `.fire`/`.fan`/`.laser`/`.switch`.
  public var switchID: Int32
  /// Pairs this teleport pad with the other pad sharing the same `teleportID`; `-1` means
  /// unlinked/inactive. Only meaningful for `.teleport`.
  public var teleportID: Int32
  /// Countdown used by `.teleport` (cooldown after use) and `.pipe` (ticks until next drip).
  public var timer: Int32
  /// Whether this teleport pad's exit is currently obstructed (so it won't teleport anything in);
  /// only meaningful for `.teleport`.
  public var blocked: Bool

  /// Remaining move budget for a climbbot's current climb segment; only meaningful for `.climbbot`.
  public var energy: Int32
  /// Whether this jump brick is currently on cooldown after launching something; only meaningful
  /// for `.jump`.
  public var active: Bool
  /// Countdown until an eyebot stops tracking/attacking after losing sight of Junkbot; only
  /// meaningful for `.eyebot`.
  public var activeTimer: Int32
  /// Whether this droplet has hit something and is playing its splash animation (rather than
  /// still falling); only meaningful for `.droplet`.
  public var splashing: Bool

  /// While `grabbed`, the fixed offset from the drag anchor to this entity's `x`, preserving the
  /// relative layout of a multi-entity drag group.
  public var grabOffsetX: Int32
  /// While `grabbed`, the fixed offset from the drag anchor to this entity's `y`, preserving the
  /// relative layout of a multi-entity drag group.
  public var grabOffsetY: Int32

  public init(id: Int32, type: EntityType, x: Int32, y: Int32, width: Int32, height: Int32) {
    self.id = id
    self.type = type
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.grabbed = false
    self.fixed = false
    self.floating = false
    self.wasFloating = false
    self.removeBeforeRender = false
    self.facing = 1
    self.facingY = 0
    self.animationFrame = 0
    self.widthInStuds = 2
    self.colorIndex = 0
    self.armored = false
    self.losingShield = false
    self.losingShieldTime = 0
    self.gettingShield = false
    self.dying = false
    self.dyingFromWater = false
    self.dead = false
    self.collectingBin = false
    self.headLoaded = false
    self.momentumX = 0
    self.momentumY = 0
    self.scaredy = false
    self.on = false
    self.used = false
    self.switchID = -1
    self.teleportID = -1
    self.timer = 0
    self.blocked = false
    self.energy = 0
    self.active = false
    self.activeTimer = 0
    self.splashing = false
    self.grabOffsetX = 0
    self.grabOffsetY = 0
  }
}
