/// The authoritative simulation state and entry point for one Junkbot level.
///
/// `GameEngine` owns the live `entities` array and everything derived from it each tick
/// (acceleration structures, wind/laser/teleport effects, win/lose state). A level is loaded via
/// `loadLevelState`/`replaceLiveState` (or the `beginLoadLevel`/`add*`/`finishLoadLevel` sequence),
/// advanced one frame at a time via `tick()`, and queried via `entities`/`winLose()`.
///
/// This class is also the extension point for the rest of `JunkbotCore`: collision queries
/// (`Collision.swift`), per-entity-type simulation (`Simulation.swift`), entity construction
/// (`EntityFactory.swift`), and level text I/O (`LevelText.swift`) are all declared as
/// `extension GameEngine` methods rather than free functions, so they share its state without
/// threading it through every call.
public final class GameEngine: @unchecked Sendable {

  // MARK: - Entity state
  /// Every live game object in the level. Order is not semantically meaningful between ticks
  /// (`simulate()` re-sorts it for gravity/rendering purposes) but IDs (`Entity.id`) are stable.
  public var entities: [Entity] = []
  /// This tick's active fan updraft effects, one per on fan entity (see `WindEffect`).
  public var wind: [WindEffect] = []
  /// This tick's active laser beams, one per on laser entity (see `LaserBeam`).
  public var laserBeams: [LaserBeam] = []
  /// Currently-playing teleport visual effects (see `TeleportEffect`).
  public var teleportEffects: [TeleportEffect] = []
  /// The level's boundary walls, if any. `nil` means the level is unbounded.
  public var levelBounds: LevelBounds? = nil

  // MARK: - Counters
  /// Monotonically increasing counter used to assign new `Entity.id`s (see `getID()`).
  var idCounter: Int32 = 0
  /// Number of `tick()`s simulated since the level was loaded.
  public var frameCounter: Int32 = 0
  /// Number of completed drag-and-drop moves made by the player, for scoring.
  public var moves: Int32 = 0
  /// The last-computed win/lose result: `0` (in progress), `1` (won), or `2` (lost). See `winOrLose()`.
  public var winLoseState: Int32 = 0

  // MARK: - Acceleration structures
  /// Maps a y-coordinate to the indices of every entity whose top edge is at that y, rebuilt each
  /// tick by `rebuildAccelerationStructures()`. Used to find what's directly above/below a
  /// position without scanning every entity (see `Collision.swift`).
  var entitiesByTopY: [Int32: [Int]] = [:]
  /// Maps a y-coordinate to the indices of every entity whose bottom edge is at that y; the
  /// counterpart to `entitiesByTopY`.
  var entitiesByBottomY: [Int32: [Int]] = [:]

  // MARK: - Input
  var mouseWorldX: Int32 = 0
  var mouseWorldY: Int32 = 0
  /// Indices into `entities` currently being dragged as a group (see `mouseDown`/`Input.swift`).
  var draggingIndices: [Int] = []
  /// Indices into `entities` that would be grabbed if the mouse were pressed right now, used for
  /// hover feedback.
  var hoveredIndices: [Int] = []

  // MARK: - Viewport
  public var viewportCenterX: Int32 = 0
  public var viewportCenterY: Int32 = 0
  public var viewportScale: Float = 1.0

  // MARK: - Level metadata
  public var levelTitle: String = ""
  public var levelHint: String = ""
  /// The target/"par" move count for scoring purposes; `Int.max` if the level has none.
  public var levelPar: Int = Int.max

  // MARK: - Flags
  /// While `true`, `tick()` is a no-op.
  public var paused: Bool = false

  // MARK: - RNG (injectable; defaults to xorshift32)
  var rngState: UInt32 = 12345
  /// Produces the next value in `[0, 1)`. Defaults to a seeded xorshift32 generator (see `init()`);
  /// replaceable for deterministic testing.
  public var rng: () -> Float = { 0 }  // replaced in init

  // MARK: - Sound callback
  /// Invoked with a `SoundID.rawValue` whenever the simulation wants to play a sound effect.
  /// The host (e.g. the JS bridge) is responsible for mapping the ID to an actual audio asset.
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

  /// A uniformly-distributed random integer in `0..<n` (or `0` if `n <= 0`).
  func randomInt(_ n: Int32) -> Int32 {
    guard n > 0 else { return 0 }
    return Int32(rng() * Float(n))
  }

  /// Returns a fresh, level-unique entity ID by incrementing `idCounter`.
  func getID() -> Int32 {
    idCounter += 1
    return idCounter
  }

  /// Clears all level state back to its just-constructed defaults. Called at the start of every
  /// level load.
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

  /// Resets and loads a complete level from an already-constructed entity list, e.g. when
  /// starting a level for the first time. Compare `replaceLiveState`, which does *not* reset
  /// (used to refresh state from a live source every tick instead of loading a level).
  public func loadLevelState(entities newEntities: [Entity], levelBounds newLevelBounds: LevelBounds?, nextID: Int32) {
    resetLevel()
    entities = newEntities
    levelBounds = newLevelBounds
    idCounter = max(nextID, maxEntityID(in: newEntities))
    rebuildAccelerationStructures()
    winLoseState = winOrLose()
  }

  /// Replaces `entities`/`levelBounds` in place without resetting other state (counters, pause
  /// flag, etc.), then rebuilds acceleration structures. Used when another source of truth (e.g.
  /// a JS-side entities array) is authoritative and this engine's state needs to be refreshed to
  /// match it before/after simulating a tick.
  public func replaceLiveState(entities newEntities: [Entity], levelBounds newLevelBounds: LevelBounds?, nextID: Int32) {
    entities = newEntities
    levelBounds = newLevelBounds
    idCounter = max(nextID, idCounter, maxEntityID(in: newEntities))
    rebuildAccelerationStructures()
  }

  /// Raises `idCounter` to at least `minValue` if it isn't already, without otherwise touching
  /// engine state. Used to stay ahead of IDs already assigned JS-side (e.g. its own `getID()`
  /// when pasting a new entity) so this engine's own `getID()` (used when spawning droplets,
  /// etc.) never collides with one JS already handed out.
  public func ensureIDCounterAtLeast(_ minValue: Int32) {
    idCounter = max(idCounter, minValue)
  }

  private func maxEntityID(in entities: [Entity]) -> Int32 {
    var result: Int32 = 0
    for entity in entities {
      if entity.id > result {
        result = entity.id
      }
    }
    return result
  }

  // MARK: - Public API

  /// Resets the RNG to a fixed seed and clears all level state. Intended for one-time setup
  /// before the first level load (use `resetLevel`/`loadLevelState` for subsequent levels, which
  /// don't re-seed the RNG).
  public func initialize() {
    rngState = 42
    resetLevel()
  }

  /// Advances the simulation by one frame, unless `paused`.
  public func tick() {
    guard !paused else { return }
    simulate()
  }

  /// Starts building a level incrementally: resets state and sets `levelBounds` (if a non-zero
  /// size is given). Follow with `add*` calls for each entity, then `finishLoadLevel()`.
  public func beginLoadLevel(_ boundsX: Int32, _ boundsY: Int32, _ boundsW: Int32, _ boundsH: Int32)
  {
    resetLevel()
    if boundsW > 0 && boundsH > 0 {
      initLevelBounds(x: boundsX, y: boundsY, width: boundsW, height: boundsH)
    }
  }

  /// Completes an incremental level load started with `beginLoadLevel`: rebuilds acceleration
  /// structures and computes the initial win/lose state.
  public func finishLoadLevel() {
    rebuildAccelerationStructures()
    winLoseState = winOrLose()
  }

  /// One `add*` method per `EntityType` for use with the `beginLoadLevel`/`finishLoadLevel`
  /// incremental level-building sequence: each appends the corresponding `make*` factory's result
  /// (see `EntityFactory.swift` for the entity's fixed dimensions and defaults) to `entities`.
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

  /// Starts a drag if the position at press-time has a grabbable entity (or entity group)
  /// beneath it; no-op if already dragging. See `Input.swift`.
  public func mouseDown(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    guard draggingIndices.isEmpty else { return }
    let grabs = possibleGrabsAt(worldX: worldX, worldY: worldY)
    if let first = grabs.first {
      startDrag(entityIndex: first, worldX: worldX, worldY: worldY)
    }
  }
  /// Updates the active drag to follow the pointer, or (if not dragging) refreshes `hoveredIndices`
  /// for hover feedback.
  public func mouseMove(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    if !draggingIndices.isEmpty {
      updateDrag(worldX: worldX, worldY: worldY)
    } else {
      hoveredIndices = possibleGrabsAt(worldX: worldX, worldY: worldY)
    }
  }
  /// Releases the active drag (if any) at its final position, committing the move.
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
  /// The last-computed win/lose result. See `winLoseState`.
  public func winLose() -> Int32 { winLoseState }
}
