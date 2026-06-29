// Grid constants (matches JS: snapX=15, snapY=18)
let CELL_W: Int32 = 15
let CELL_H: Int32 = 18

let TELEPORT_COOLDOWN: Int32 = 50
let TELEPORT_EFFECT_PERIOD: Int32 = 20
let MAX_DRIP_PERIOD: Int32 = 50
let MIN_DRIP_PERIOD: Int32 = 20

enum EntityType: UInt8 {
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

struct LevelBounds {
    var x: Int32
    var y: Int32
    var width: Int32
    var height: Int32
}

struct WindEffect {
    var fanEntityIndex: Int
    // up to 8 columns for a 8-stud-wide fan
    var numExtents: Int
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

    func extent(at i: Int) -> Int32 {
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

struct LaserBeam {
    var laserEntityIndex: Int
    var extent: Int32
    var hitEntityIndex: Int  // -1 = hit nothing / level bounds
}

struct TeleportEffect {
    var x: Int32
    var y: Int32
    var frameIndex: Int32
}

// Large unified entity struct. All fields; most unused for any given type.
struct Entity {
    var id: Int32
    var type: EntityType
    var x: Int32
    var y: Int32
    var width: Int32
    var height: Int32

    var grabbed: Bool
    var fixed: Bool
    var floating: Bool
    var wasFloating: Bool
    var removeBeforeRender: Bool

    // Directional state
    var facing: Int32     // 1=right, -1=left
    var facingY: Int32    // 0=none, 1=down, -1=up
    var animationFrame: Int32

    // Brick fields
    var widthInStuds: Int32
    var colorIndex: Int32   // 0=white,1=red,2=green,3=blue,4=yellow,5=gray

    // Junkbot fields
    var armored: Bool
    var losingShield: Bool
    var losingShieldTime: Int32
    var gettingShield: Bool
    var dying: Bool
    var dyingFromWater: Bool
    var dead: Bool
    var collectingBin: Bool
    var headLoaded: Bool
    var momentumX: Int32
    var momentumY: Int32

    // Bin
    var scaredy: Bool

    // Switch / fan / fire / laser / teleport
    var on: Bool
    var used: Bool
    var switchID: Int32   // -1 = none
    var teleportID: Int32 // -1 = none
    var timer: Int32
    var blocked: Bool

    // Climbbot
    var energy: Int32

    // Jump
    var active: Bool

    // Eyebot
    var activeTimer: Int32

    // Droplet
    var splashing: Bool

    // Grab offset (when entity is being dragged)
    var grabOffsetX: Int32
    var grabOffsetY: Int32

    init(id: Int32, type: EntityType, x: Int32, y: Int32, width: Int32, height: Int32) {
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
