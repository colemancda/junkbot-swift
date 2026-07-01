public final class GameEngine: @unchecked Sendable {

  // MARK: - Entity state
  public var entities: [Entity] = []
  public var wind: [WindEffect] = []
  public var laserBeams: [LaserBeam] = []
  public var teleportEffects: [TeleportEffect] = []
  public var levelBounds: LevelBounds? = nil

  // MARK: - Counters
  var idCounter: Int32 = 0
  public var frameCounter: Int32 = 0
  public var moves: Int32 = 0
  public var winLoseState: Int32 = 0

  // MARK: - Acceleration structures
  var entitiesByTopY: [Int32: [Int]] = [:]
  var entitiesByBottomY: [Int32: [Int]] = [:]

  // MARK: - Input
  var mouseWorldX: Int32 = 0
  var mouseWorldY: Int32 = 0
  var draggingIndices: [Int] = []
  var hoveredIndices: [Int] = []

  // MARK: - Viewport
  public var viewportCenterX: Int32 = 0
  public var viewportCenterY: Int32 = 0
  public var viewportScale: Float = 1.0

  // MARK: - Level metadata
  public var levelTitle: String = ""
  public var levelHint: String = ""
  public var levelPar: Int = Int.max

  // MARK: - Flags
  public var paused: Bool = false

  // MARK: - RNG (injectable; defaults to xorshift32)
  var rngState: UInt32 = 12345
  public var rng: () -> Float = { 0 }  // replaced in init

  // MARK: - Sound callback
  public var onPlaySound: ((Int32) -> Void)? = nil

  public init() {
    rng = { [unowned(unsafe) self] in
      self.rngState ^= self.rngState << 13
      self.rngState ^= self.rngState >> 17
      self.rngState ^= self.rngState << 5
      return Float(self.rngState & 0x7FFF_FFFF) / Float(0x7FFF_FFFF)
    }
  }

  // MARK: - Helpers

  func playSound(_ id: SoundID) {
    onPlaySound?(id.rawValue)
  }

  func randomFloat() -> Float { rng() }

  func randomInt(_ n: Int32) -> Int32 {
    guard n > 0 else { return 0 }
    return Int32(rng() * Float(n))
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
    levelTitle = ""
    levelHint = ""
    levelPar = Int.max
  }

  // MARK: - Public API

  public func initialize() {
    rngState = 42
    resetLevel()
  }

  public func tick() {
    guard !paused else { return }
    simulate()
  }

  public func beginLoadLevel(_ boundsX: Int32, _ boundsY: Int32, _ boundsW: Int32, _ boundsH: Int32)
  {
    resetLevel()
    if boundsW > 0 && boundsH > 0 {
      initLevelBounds(x: boundsX, y: boundsY, width: boundsW, height: boundsH)
    }
  }

  public func finishLoadLevel() {
    rebuildAccelerationStructures()
    winLoseState = winOrLose()
  }

  public func addBrick(
    _ x: Int32, _ y: Int32, _ widthInStuds: Int32, _ colorIndex: Int32, _ fixed: Bool
  ) {
    entities.append(
      makeBrick(x: x, y: y, widthInStuds: widthInStuds, colorIndex: colorIndex, fixed: fixed))
  }
  public func addJunkbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ armored: Bool) {
    entities.append(makeJunkbot(x: x, y: y, facing: facing, armored: armored))
  }
  public func addGearbot(_ x: Int32, _ y: Int32, _ facing: Int32) {
    entities.append(makeGearbot(x: x, y: y, facing: facing))
  }
  public func addClimbbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32) {
    entities.append(makeClimbbot(x: x, y: y, facing: facing, facingY: facingY))
  }
  public func addFlybot(_ x: Int32, _ y: Int32, _ facing: Int32) {
    entities.append(makeFlybot(x: x, y: y, facing: facing))
  }
  public func addEyebot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32) {
    entities.append(makeEyebot(x: x, y: y, facing: facing, facingY: facingY))
  }
  public func addBin(_ x: Int32, _ y: Int32, _ facing: Int32, _ scaredy: Bool) {
    entities.append(makeBin(x: x, y: y, facing: facing, scaredy: scaredy))
  }
  public func addCrate(_ x: Int32, _ y: Int32) {
    entities.append(makeCrate(x: x, y: y))
  }
  public func addFire(_ x: Int32, _ y: Int32, _ on: Bool, _ switchID: Int32) {
    entities.append(makeFire(x: x, y: y, on: on, switchID: switchID))
  }
  public func addFan(_ x: Int32, _ y: Int32, _ on: Bool, _ switchID: Int32) {
    entities.append(makeFan(x: x, y: y, on: on, switchID: switchID))
  }
  public func addSwitch(_ x: Int32, _ y: Int32, _ on: Bool, _ switchID: Int32) {
    entities.append(makeSwitch(x: x, y: y, on: on, switchID: switchID))
  }
  public func addPipe(_ x: Int32, _ y: Int32) {
    entities.append(makePipe(x: x, y: y))
  }
  public func addShield(_ x: Int32, _ y: Int32, _ used: Bool, _ fixed: Bool) {
    entities.append(makeShield(x: x, y: y, used: used, fixed: fixed))
  }
  public func addJump(_ x: Int32, _ y: Int32, _ fixed: Bool) {
    entities.append(makeJump(x: x, y: y, fixed: fixed))
  }
  public func addTeleport(_ x: Int32, _ y: Int32, _ teleportID: Int32) {
    entities.append(makeTeleport(x: x, y: y, teleportID: teleportID))
  }
  public func addLaser(_ x: Int32, _ y: Int32, _ facing: Int32, _ on: Bool, _ switchID: Int32) {
    entities.append(makeLaser(x: x, y: y, facing: facing, on: on, switchID: switchID))
  }

  public func mouseDown(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    guard draggingIndices.isEmpty else { return }
    let grabs = possibleGrabsAt(worldX: worldX, worldY: worldY)
    if let first = grabs.first {
      startDrag(entityIndex: first, worldX: worldX, worldY: worldY)
    }
  }
  public func mouseMove(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    if !draggingIndices.isEmpty {
      updateDrag(worldX: worldX, worldY: worldY)
    } else {
      hoveredIndices = possibleGrabsAt(worldX: worldX, worldY: worldY)
    }
  }
  public func mouseUp(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    if !draggingIndices.isEmpty {
      updateDrag(worldX: worldX, worldY: worldY)
      finishDrag()
    }
  }
  public func setPaused(_ isPaused: Bool) { paused = isPaused }
  public func setViewport(_ cx: Int32, _ cy: Int32, _ scale: Float) {
    viewportCenterX = cx
    viewportCenterY = cy
    viewportScale = scale
  }
  public func winLose() -> Int32 { winLoseState }
}
