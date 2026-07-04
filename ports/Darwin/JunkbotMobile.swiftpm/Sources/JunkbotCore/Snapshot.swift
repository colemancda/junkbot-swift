/// A complete, restorable copy of `GameEngine`'s mutable simulation state at one instant, used by
/// both per-move undo (`Undo.swift`'s `undo()`) and per-tick rewind (`stepRewind()`). `Entity` is
/// a plain value type in a `[Entity]` array (copy-on-write), so capturing a snapshot is cheap —
/// no serialization needed, unlike the JSON-diff-patch approach this replaces on the JS side.
///
/// Deliberately excludes:
/// - Level metadata that never changes after load (`levelBounds`/`levelTitle`/`levelHint`/
///   `levelPar`) — no need to snapshot per-tick.
/// - Derived/rebuildable state (`entitiesByTopY`/`entitiesByBottomY`) — `restore(_:)` calls
///   `rebuildAccelerationStructures()` instead of snapshotting these.
/// - Camera/UI state (`viewportCenterX/Y`/`viewportScale`/`paused`) — restoring these would fight
///   the player's current camera position and pause intent.
/// - Input-gesture-transient state (`draggingIndices`, `pendingGrabUpward/Downward`,
///   `hoveredIndices`, `mouseWorldX/Y`, `mouseDownWorldX/Y`) — undo/rewind only ever fire with no
///   drag in progress, so these are always at their default/empty values at snapshot time.
struct EngineSnapshot {
  var entities: [Entity]
  var wind: [WindEffect]
  var laserBeams: [LaserBeam]
  var teleportEffects: [TeleportEffect]
  var idCounter: Int32
  var frameCounter: Int32
  var moves: Int32
  var winLoseState: Int32
  /// So a restore reproduces the exact same *future* RNG sequence (droplet spawn timing, etc.)
  /// that would have happened originally, not a different one.
  var rngState: UInt32
}
