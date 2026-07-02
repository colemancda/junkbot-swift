/// Native-only drag-and-drop input handling, driving `GameEngine.mouseDown`/`mouseMove`/`mouseUp`.
///
/// Ports JS's play-mode grab/drag/release logic (`possibleGrabs`/`startGrab`/`updateDrag`/
/// `canRelease`/`finishDrag` in `src/game.js`) to operate on `GameEngine.entities` by index
/// instead of live JS objects. Editor-mode-only behavior (ctrl-click, multi-select, bypassing the
/// fixed/grabbable checks while editing) is deliberately NOT ported — editor-mode dragging stays
/// JS-side, using the WASM-bridge logic in `main.swift` (`possibleGrabsCore`/`entitiesConnect`/
/// etc.) unchanged. Used by any host embedding `GameEngine` directly; the WASM/browser bridge
/// wires play-mode mouse events to `mouseDown`/`mouseMove`/`mouseUp` below.
///
/// One disclosed simplification from JS: the up/down grab-direction resolution threshold
/// (`dragResolveThreshold`) is measured in world-space pixels here, whereas JS measures 10
/// *canvas*-space pixels (so its effective world-space threshold varies with zoom level). This
/// only affects how far you must drag before the direction commits, not which entities end up
/// grabbable in each direction — a minor feel difference, not a correctness/rules gap.
extension GameEngine {

  /// World-space vertical distance the pointer must move from its press position before a
  /// two-directions-possible grab (see `pendingGrabUpward`/`pendingGrabDownward`) resolves to
  /// upward or downward. See this file's header comment re: JS's canvas-space equivalent.
  var dragResolveThreshold: Int32 { CELL_H / 2 }

  /// Indices of every grabbable (not `fixed`, not already `grabbed`, `brick`/`jump`/`shield`)
  /// entity whose bounds contain the given world position. Matches JS's play-mode allowlist in
  /// `possibleGrabs` exactly (other types, e.g. crates or hazards, are never play-mode-draggable
  /// even though they aren't `fixed`).
  func possibleGrabsAt(worldX: Int32, worldY: Int32) -> [Int] {
    var result: [Int] = []
    for i in 0..<entities.count {
      let e = entities[i]
      if e.fixed { continue }
      if e.grabbed { continue }
      guard e.type == .brick || e.type == .jump || e.type == .shield else { continue }
      if worldX >= e.x && worldX < e.x + e.width && worldY >= e.y && worldY < e.y + e.height {
        result.append(i)
      }
    }
    return result
  }

  /// Finds the group of un-fixed brick/jump/shield entities that would need to move together if
  /// `startIndex` were grabbed and dragged in `direction` (`1` = downward, following bricks
  /// resting below; `-1` = upward, following bricks resting above — matches `connects`'
  /// direction convention). Returns `nil` if the direction-limited traversal hits something
  /// ungrabbable (a `fixed` entity, or any non-brick entity) — that direction isn't grabbable at
  /// all. Otherwise also sweeps in any additional un-fixed brick/jump/shield neighbor of the
  /// resulting group that isn't independently anchored to something fixed (so it would be left
  /// unsupported if not grabbed too), unless blocked by non-brick "junk" resting on that neighbor
  /// (in which case the whole grab is disallowed). Index-based port of `main.swift`'s
  /// `possibleGrabsCore`/`findAttached`.
  func findAttachedGroup(startIndex: Int, direction: Int32) -> [Int]? {
    var attached: [Int] = [startIndex]

    func walkInitialDirection(_ index: Int) -> Bool {
      for other in 0..<entities.count {
        guard other != index, !attached.contains(other) else { continue }
        let isBrick = entities[other].type == .brick
        guard connects(index, other, direction: isBrick ? direction : -1) else { continue }
        if entities[other].fixed || !isBrick { return false }
        attached.append(other)
        if !walkInitialDirection(other) { return false }
      }
      return true
    }
    guard walkInitialDirection(startIndex) else { return nil }

    func isBlockedByJunkAbove(_ entityIndex: Int) -> Bool {
      let e = entities[entityIndex]
      for other in 0..<entities.count {
        guard other != entityIndex, entities[other].type != .brick else { continue }
        let o = entities[other]
        guard o.y + o.height == e.y else { continue }
        guard e.x + e.width > o.x && e.x < o.x + o.width else { continue }
        return true
      }
      return false
    }

    // Sweep in dependent neighbors (both directions) that aren't independently fixed-connected;
    // a worklist over `attached` (which grows during iteration) so newly-swept-in neighbors are
    // themselves checked for their own dependents, matching JS's live-array `for...of` traversal.
    var i = 0
    while i < attached.count {
      let brickIndex = attached[i]
      for other in 0..<entities.count {
        guard other != brickIndex, !attached.contains(other) else { continue }
        let o = entities[other]
        guard !o.fixed, o.type == .brick || o.type == .jump || o.type == .shield else { continue }
        guard connects(brickIndex, other) else { continue }
        let ctf = connectsToFixed(startIndex: other, direction: 0, ignoreIndices: attached)
        if ctf { continue }
        if isBlockedByJunkAbove(other) { return nil }
        attached.append(other)
      }
      i += 1
    }
    return attached
  }

  /// Computes both possible grab groups for the grabbable entity at `startIndex`: dragging it
  /// downward (following what rests below) or upward (following what rests above). Index-based
  /// port of `main.swift`'s `possibleGrabsCore`.
  func possibleGrabsInDirections(startIndex: Int)
    -> (canGrabDownward: Bool, grabDownward: [Int], canGrabUpward: Bool, grabUpward: [Int])
  {
    let downward = findAttachedGroup(startIndex: startIndex, direction: 1)
    let upward = findAttachedGroup(startIndex: startIndex, direction: -1)
    return (downward != nil, downward ?? [startIndex], upward != nil, upward ?? [startIndex])
  }

  /// Begins dragging every entity in `indices` as a group, recording each dragged entity's offset
  /// from the grab point so their relative layout is preserved as the group moves. No-op if the
  /// first entity is already `grabbed`.
  func startDrag(indices: [Int], worldX: Int32, worldY: Int32) {
    guard let first = indices.first, !entities[first].grabbed else { return }
    draggingIndices = indices
    moves += 1
    for idx in draggingIndices {
      entities[idx].grabbed = true
      entities[idx].grabOffsetX = entities[idx].x - worldX
      entities[idx].grabOffsetY = entities[idx].y - worldY
    }
    playSound(.blockPickUp)
  }

  /// Moves the entire `draggingIndices` group to follow the pointer, snapped to the grid and
  /// preserving each entity's offset from the drag anchor (`draggingIndices[0]`).
  func updateDrag(worldX: Int32, worldY: Int32) {
    guard !draggingIndices.isEmpty else { return }
    let baseIdx = draggingIndices[0]
    let snapWorldX = snapToGrid(worldX + entities[baseIdx].grabOffsetX, CELL_W)
    let snapWorldY = snapToGrid(worldY + entities[baseIdx].grabOffsetY, CELL_H)
    let dx = snapWorldX - entities[baseIdx].x
    let dy = snapWorldY - entities[baseIdx].y
    if dx != 0 || dy != 0 {
      for idx in draggingIndices {
        entities[idx].x += dx
        entities[idx].y += dy
      }
    }
  }

  /// Ends the current drag: clears `grabbed` on every dragged entity, refreshes their
  /// acceleration-structure entries, and plays the drop sound. Callers must check `canRelease()`
  /// first (see `mouseUp`) — unlike the pre-`canRelease`-gating version of this function, it no
  /// longer re-checks placement validity itself, since by contract every call now represents an
  /// already-confirmed-valid placement (matching JS's `finishDrag`, which only ever commits after
  /// its own `canRelease()` gate passes).
  func finishDrag() {
    guard !draggingIndices.isEmpty else { return }
    for idx in draggingIndices {
      entities[idx].grabbed = false
      entityMoved(index: idx)
    }
    playSound(.blockDrop)
    draggingIndices.removeAll(keepingCapacity: true)
  }

  /// Whether the currently-dragged group could be released at its present position: no collision
  /// with anything solid, not adjacent to an active `fire`/`fan` hazard, and connected to
  /// something transitively fixed (a brick or the level floor) on exactly one vertical side —
  /// ceiling *or* floor, not both (over-constrained) and not neither (would float unsupported).
  /// Matches JS's `canRelease` (`src/game.js`) exactly, for the play-mode case (no `editing`
  /// bypass, since editor-mode dragging stays JS-side — see this file's header comment).
  public func canRelease() -> Bool {
    guard !draggingIndices.isEmpty else { return false }
    guard !paused else { return false }

    // Fail if any dragged entity collides with a non-grabbed, non-droplet entity.
    for idx in draggingIndices {
      let e = entities[idx]
      if entityCollisionTest(
        entityX: e.x, entityY: e.y, entityIndex: idx,
        filter: { !$0.grabbed && $0.type != .droplet }) != nil
      {
        return false
      }
    }

    if draggingIndices.allSatisfy({ entities[$0].fixed }) { return true }

    let connectedToFixed = allConnectedToFixed()
    var connectsCeiling = false
    var connectsFloor = false

    for dIdx in draggingIndices {
      for otherIdx in 0..<entities.count {
        let other = entities[otherIdx]
        if other.grabbed { continue }
        if (other.type == .fire || other.type == .fan) && connects(dIdx, otherIdx) {
          return false
        }
        if other.type == .brick && connectedToFixed.contains(otherIdx) {
          if connects(dIdx, otherIdx, direction: -1) { connectsCeiling = true }
          if connects(dIdx, otherIdx, direction: 1) { connectsFloor = true }
        }
      }
    }

    return connectsCeiling != connectsFloor
  }

  /// Rounds `value` to the nearest multiple of `grid`, rounding up on exact ties.
  func snapToGrid(_ value: Int32, _ grid: Int32) -> Int32 {
    let r = value % grid
    if r == 0 { return value }
    if r < grid / 2 { return value - r }
    return value - r + grid
  }
}
