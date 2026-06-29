// Global game state mirroring the JS globals

var entities: [Entity] = []
var wind: [WindEffect] = []
var laserBeams: [LaserBeam] = []
var teleportEffects: [TeleportEffect] = []

var levelBounds: LevelBounds? = nil
var idCounter: Int32 = 0

var frameCounter: Int32 = 0
var moves: Int32 = 0

// 0=playing, 1=won, 2=lost
var winLoseState: Int32 = 0

// Acceleration structures: y-coordinate → array of entity indices
var entitiesByTopY: [Int32: [Int]] = [:]
var entitiesByBottomY: [Int32: [Int]] = [:]

// Input state
var mouseWorldX: Int32 = 0
var mouseWorldY: Int32 = 0

// Indices of entities currently being dragged
var draggingIndices: [Int] = []
// Indices of possible grabs (hovered) – used for cursor display
var hoveredIndices: [Int] = []

// Keys held (subset needed for simulation; rest handled by JS)
var keyShiftHeld: Bool = false

// Viewport
var viewportCenterX: Int32 = 0
var viewportCenterY: Int32 = 0
var viewportScale: Float = 1.0

// Flags
var paused: Bool = false
var editing: Bool = false
var muted: Bool = false

// Random number state (xorshift32)
var rngState: UInt32 = 12345

func randomFloat() -> Float {
    rngState ^= rngState << 13
    rngState ^= rngState >> 17
    rngState ^= rngState << 5
    return Float(rngState & 0x7FFFFFFF) / Float(0x7FFFFFFF)
}

func randomInt(_ n: Int32) -> Int32 {
    guard n > 0 else { return 0 }
    return Int32(randomFloat() * Float(n))
}

func getID() -> Int32 {
    idCounter += 1
    return idCounter
}

func resetLevel() {
    entities.removeAll(keepingCapacity: true)
    wind.removeAll(keepingCapacity: true)
    laserBeams.removeAll(keepingCapacity: true)
    teleportEffects.removeAll(keepingCapacity: true)
    entitiesByTopY.removeAll(keepingCapacity: true)
    entitiesByBottomY.removeAll(keepingCapacity: true)
    draggingIndices.removeAll(keepingCapacity: true)
    hoveredIndices.removeAll(keepingCapacity: true)
    idCounter = 0
    frameCounter = 0
    moves = 0
    winLoseState = 0
    levelBounds = nil
    paused = false
}
