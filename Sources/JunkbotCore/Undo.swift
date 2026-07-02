/// Play-mode undo (`undo()`) and rewind (`beginRewind`/`stepRewind`/`endRewind`), both backed by
/// `EngineSnapshot` (see `Snapshot.swift`). This is a separate, new capability from the level
/// editor's own undo/redo (JS-side, full-level-JSON-snapshot based, `editing`-gated) — that
/// system is untouched; this one is for play mode, driven by `Input.swift`'s `startDrag` (which
/// pushes an undo snapshot before each move) and `Simulation.swift`'s `simulate()` (which pushes
/// a rewind snapshot every tick).
extension GameEngine {

  /// Reverts the last completed move (a drag pickup-through-place). No-op, returning `false`, if
  /// there's nothing to undo, a drag is currently in progress, or a rewind is active.
  @discardableResult
  public func undo() -> Bool {
    guard draggingIndices.isEmpty, !isRewinding, let snapshot = undoStack.popLast() else {
      return false
    }
    restore(snapshot)
    playSound(.undo)
    return true
  }

  /// Whether `undo()` would currently do anything — for a host to enable/disable an Undo control.
  public var canUndo: Bool { !undoStack.isEmpty }

  /// Begins a rewind gesture (e.g. holding Shift): pauses the simulation without discarding
  /// rewind history. Idempotent — calling again while already rewinding does nothing.
  public func beginRewind() {
    guard !isRewinding else { return }
    isRewinding = true
    wasPausedBeforeRewind = paused
    paused = true
  }

  /// Steps the simulation backward by one buffered tick (call this once per desired step, e.g.
  /// `rewindRate` times per frame while the rewind key/button is held, matching the JS host's
  /// existing cadence). Returns `false` (no-op) once `frameCounter` reaches `0`, or if the needed
  /// history has already been overwritten by the ring buffer wrapping around.
  @discardableResult
  public func stepRewind() -> Bool {
    guard isRewinding, frameCounter > 0 else { return false }
    let targetFrame = frameCounter - 1
    guard let snapshot = rewindBuffer[Int(targetFrame) % rewindBuffer.count],
      // A slot that's been wrapped-around-past holds a *different*, more recent tick's snapshot
      // rather than nil — check the snapshot's own frameCounter actually matches what we're
      // looking for, so we fail closed instead of silently restoring the wrong frame's state.
      snapshot.frameCounter == targetFrame
    else { return false }
    restore(snapshot)
    return true
  }

  /// Ends a rewind gesture, restoring whatever pause state was in effect before it began.
  public func endRewind() {
    guard isRewinding else { return }
    isRewinding = false
    paused = wasPausedBeforeRewind
  }

  func snapshot() -> EngineSnapshot {
    EngineSnapshot(
      entities: entities, wind: wind, laserBeams: laserBeams, teleportEffects: teleportEffects,
      idCounter: idCounter, frameCounter: frameCounter, moves: moves, winLoseState: winLoseState,
      rngState: rngState)
  }

  func restore(_ snapshot: EngineSnapshot) {
    entities = snapshot.entities
    wind = snapshot.wind
    laserBeams = snapshot.laserBeams
    teleportEffects = snapshot.teleportEffects
    idCounter = snapshot.idCounter
    frameCounter = snapshot.frameCounter
    moves = snapshot.moves
    winLoseState = snapshot.winLoseState
    rngState = snapshot.rngState
    rebuildAccelerationStructures()
  }
}
