// Grid constants (matches JS: snapX=15, snapY=18)
public let CELL_W: Int32 = 15
public let CELL_H: Int32 = 18

let TELEPORT_COOLDOWN: Int32 = 50
let TELEPORT_EFFECT_PERIOD: Int32 = 20
let MAX_DRIP_PERIOD: Int32 = 50
let MIN_DRIP_PERIOD: Int32 = 20

public enum EntityType: UInt8 {
    case brick = 0
    case junkbot = 1
    case gearbot = 2
    case climbbot = 3
    case flybot = 4
    case eyebot = 5
    case bin = 6
    case crate = 7
    case fire = 8
    case fan = 9
    case `switch` = 10
    case pipe = 11
    case shield = 12
    case teleport = 13
    case laser = 14
    case jump = 15
    case droplet = 16
    case levelBounds = 17
    case unknown = 255
}

// Sound indices (must match harness.js)
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

public struct LevelBounds {
    public var x: Int32
    public var y: Int32
    public var width: Int32
    public var height: Int32
}

public struct WindEffect {
    public var fanEntityIndex: Int
    public var numExtents: Int
    var extents: (Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32)

    init(fanEntityIndex: Int) {
        self.fanEntityIndex = fanEntityIndex
        self.numExtents = 0
        self.extents = (0, 0, 0, 0, 0, 0, 0, 0)
    }

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

public struct LaserBeam {
    public var laserEntityIndex: Int
    public var extent: Int32
    public var hitEntityIndex: Int
}

public struct TeleportEffect {
    public var x: Int32
    public var y: Int32
    public var frameIndex: Int32
}

// Large unified entity struct. All fields; most unused for any given type.
public struct Entity {
    public var id: Int32
    public var type: EntityType
    public var x: Int32
    public var y: Int32
    public var width: Int32
    public var height: Int32

    public var grabbed: Bool
    public var fixed: Bool
    public var floating: Bool
    public var wasFloating: Bool
    public var removeBeforeRender: Bool

    public var facing: Int32
    public var facingY: Int32
    public var animationFrame: Int32

    public var widthInStuds: Int32
    public var colorIndex: Int32

    public var armored: Bool
    public var losingShield: Bool
    public var losingShieldTime: Int32
    public var gettingShield: Bool
    public var dying: Bool
    public var dyingFromWater: Bool
    public var dead: Bool
    public var collectingBin: Bool
    public var headLoaded: Bool
    public var momentumX: Int32
    public var momentumY: Int32

    public var scaredy: Bool

    public var on: Bool
    public var used: Bool
    public var switchID: Int32
    public var teleportID: Int32
    public var timer: Int32
    public var blocked: Bool

    public var energy: Int32
    public var active: Bool
    public var activeTimer: Int32
    public var splashing: Bool

    public var grabOffsetX: Int32
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
