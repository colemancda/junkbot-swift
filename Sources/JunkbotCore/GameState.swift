// Global game state

public nonisolated(unsafe) var entities: [Entity] = []
public nonisolated(unsafe) var wind: [WindEffect] = []
public nonisolated(unsafe) var laserBeams: [LaserBeam] = []
public nonisolated(unsafe) var teleportEffects: [TeleportEffect] = []

public nonisolated(unsafe) var levelBounds: LevelBounds? = nil
nonisolated(unsafe) var idCounter: Int32 = 0

public nonisolated(unsafe) var frameCounter: Int32 = 0
public nonisolated(unsafe) var moves: Int32 = 0

// 0=playing, 1=won, 2=lost
public nonisolated(unsafe) var winLoseState: Int32 = 0

// Acceleration structures: y-coordinate → array of entity indices
nonisolated(unsafe) var entitiesByTopY: [Int32: [Int]] = [:]
nonisolated(unsafe) var entitiesByBottomY: [Int32: [Int]] = [:]

// Input state
nonisolated(unsafe) var mouseWorldX: Int32 = 0
nonisolated(unsafe) var mouseWorldY: Int32 = 0

// Indices of entities currently being dragged
nonisolated(unsafe) var draggingIndices: [Int] = []
// Indices of possible grabs (hovered)
nonisolated(unsafe) var hoveredIndices: [Int] = []

nonisolated(unsafe) var keyShiftHeld: Bool = false

// Viewport
public nonisolated(unsafe) var viewportCenterX: Int32 = 0
public nonisolated(unsafe) var viewportCenterY: Int32 = 0
public nonisolated(unsafe) var viewportScale: Float = 1.0

// Flags
public nonisolated(unsafe) var paused: Bool = false
nonisolated(unsafe) var editing: Bool = false
nonisolated(unsafe) var muted: Bool = false

// Random number state (xorshift32)
nonisolated(unsafe) var rngState: UInt32 = 12345

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

public func resetLevel() {
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
