/// Native-only drag-and-drop input handling, driving `GameEngine.mouseDown`/`mouseMove`/`mouseUp`.
///
/// This is a simpler, self-contained alternative to the JS-bridge grab logic in `main.swift`
/// (`possibleGrabsCore`/`entitiesConnect`/etc. in `JunkbotApp`, which the browser build actually
/// uses): it only ever grabs a brick together with whatever's directly stacked above it
/// (`attachedAbove`), rather than JS's fuller up/down-direction, sandwich-detection logic. Used
/// by any host embedding `GameEngine` directly (see `GameEngine.mouseDown`/`mouseMove`/`mouseUp`),
/// not by the WASM/browser bridge.
extension GameEngine {

  /// Indices of every grabbable (not `fixed`, not already `grabbed`, not an enemy/junkbot/droplet)
  /// entity whose bounds contain the given world position.
  func possibleGrabsAt(worldX: Int32, worldY: Int32) -> [Int] {
    var result: [Int] = []
    for i in 0..<entities.count {
      let e = entities[i]
      if e.fixed { continue }
      if e.grabbed { continue }
      if e.type == .junkbot || e.type == .gearbot || e.type == .climbbot || e.type == .flybot
        || e.type == .eyebot || e.type == .droplet
      {
        continue
      }
      if worldX >= e.x && worldX < e.x + e.width && worldY >= e.y && worldY < e.y + e.height {
        result.append(i)
      }
    }
    return result
  }

  /// Indices of every grabbable entity transitively stacked directly on top of `startIndex`
  /// (excluding `startIndex` itself), so dragging one brick carries the tower above it along.
  func attachedAbove(startIndex: Int) -> [Int] {
    var result: [Int] = []
    var frontier: [Int] = [startIndex]
    while !frontier.isEmpty {
      let current = frontier.removeLast()
      let e = entities[current]
      let topY = e.y
      for i in 0..<entities.count {
        if i == current { continue }
        if result.contains(i) || i == startIndex { continue }
        let other = entities[i]
        if other.fixed { continue }
        if other.type == .junkbot || other.type == .gearbot || other.type == .climbbot
          || other.type == .flybot || other.type == .eyebot || other.type == .droplet
        {
          continue
        }
        if other.y + other.height == topY && other.x + other.width > e.x && other.x < e.x + e.width
        {
          result.append(i)
          frontier.append(i)
        }
      }
    }
    return result
  }

  /// Begins dragging `entityIndex` together with `attachedAbove(startIndex:)`, recording each
  /// dragged entity's offset from the grab point so their relative layout is preserved as the
  /// group moves. No-op if `entityIndex` is already `grabbed`.
  func startDrag(entityIndex: Int, worldX: Int32, worldY: Int32) {
    guard !entities[entityIndex].grabbed else { return }
    draggingIndices = [entityIndex] + attachedAbove(startIndex: entityIndex)
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
  /// acceleration-structure entries, and plays a drop (if the final position doesn't collide with
  /// anything solid) or reject (if it does) sound. Does not undo the move on collision — that's
  /// `canRelease()`'s job to check *before* calling this.
  func finishDrag() {
    guard !draggingIndices.isEmpty else { return }
    var canPlace = true
    for idx in draggingIndices {
      let e = entities[idx]
      if entityCollisionTest(
        entityX: e.x, entityY: e.y, entityIndex: idx,
        filter: { other in
          !other.grabbed && other.type != .droplet
        }) != nil
      {
        canPlace = false
        break
      }
    }
    for idx in draggingIndices {
      entities[idx].grabbed = false
      entityMoved(index: idx)
    }
    playSound(canPlace ? .blockDrop : .blockClick)
    draggingIndices.removeAll(keepingCapacity: true)
  }

  /// Whether the currently-dragged group could be released at its present position: no collision
  /// with anything solid, and connected to something fixed (a brick or the level floor) on
  /// exactly one vertical side — ceiling *or* floor, not both (would be over-constrained) and not
  /// neither (would float unsupported). Matches the original game's placement rule.
  public func canRelease() -> Bool {
    guard !draggingIndices.isEmpty else { return false }

    // Fail if any dragged entity collides with a non-grabbed entity
    for idx in draggingIndices {
      let e = entities[idx]
      if entityCollisionTest(
        entityX: e.x, entityY: e.y, entityIndex: idx,
        filter: {
          !$0.grabbed && $0.type != .droplet
        }) != nil
      {
        return false
      }
    }

    var connectsCeiling = false
    var connectsFloor = false

    for idx in draggingIndices {
      let e = entities[idx]
      for i in 0..<entities.count {
        let other = entities[i]
        guard !other.grabbed && other.type == .brick else { continue }
        guard other.x + other.width > e.x && other.x < e.x + e.width else { continue }
        // ceiling: other sits directly above e
        if other.y + other.height == e.y { connectsCeiling = true }
        // floor: other sits directly below e
        if e.y + e.height == other.y { connectsFloor = true }
      }
      // level floor counts as floor connection
      if let bounds = levelBounds, e.y + e.height >= bounds.y + bounds.height {
        connectsFloor = true
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
