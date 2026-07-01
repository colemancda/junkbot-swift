/// Collision queries and the y-indexed acceleration structures they're built on. Everything here
/// operates on `GameEngine.entities` by index (rather than returning/taking references), since
/// `Entity` is a value type — callers that need to mutate a hit result must look it up again by
/// its returned index.
extension GameEngine {

  /// Whether axis-aligned rectangle A (`ax, ay, aw, ah`) overlaps rectangle B (`bx, by, bw, bh`).
  /// Touching edges do not count as overlapping.
  public func rectanglesIntersect(
    _ ax: Int32, _ ay: Int32, _ aw: Int32, _ ah: Int32,
    _ bx: Int32, _ by: Int32, _ bw: Int32, _ bh: Int32
  ) -> Bool {
    ax + aw > bx && ax < bx + bw && ay + ah > by && ay < by + bh
  }

  /// If the given rectangle crosses outside `levelBounds`, returns a synthetic `.levelBounds`
  /// entity representing whichever boundary wall it crossed (never actually stored in `entities`).
  /// Returns `nil` if there are no bounds, or the rectangle is fully within them.
  public func rectangleLevelBoundsCollision(x: Int32, y: Int32, width: Int32, height: Int32) -> Entity? {
    guard let bounds = levelBounds else { return nil }
    var e = Entity(id: -1, type: .levelBounds, x: 0, y: 0, width: 0, height: 0)
    e.fixed = true
    if x < bounds.x {
      e.x = bounds.x - CELL_W
      e.y = bounds.y
      e.width = CELL_W
      e.height = bounds.height
      return e
    }
    if y < bounds.y {
      e.x = bounds.x
      e.y = bounds.y - CELL_H
      e.width = bounds.width
      e.height = CELL_H
      return e
    }
    if x + width > bounds.x + bounds.width {
      e.x = bounds.x + bounds.width
      e.y = bounds.y
      e.width = CELL_W
      e.height = bounds.height
      return e
    }
    if y + height > bounds.y + bounds.height {
      e.x = bounds.x
      e.y = bounds.y + bounds.height
      e.width = bounds.width
      e.height = CELL_H
      return e
    }
    return nil
  }

  // MARK: - Common collision filters
  // Reusable `filter` predicates for the collision queries below, named for what they exclude.

  func isNotDroplet(_ e: Entity) -> Bool { e.type != .droplet }
  func isNotBinOrDroplet(_ e: Entity) -> Bool { e.type != .bin && e.type != .droplet }
  func isNotBinOrDropletOrEnemyBot(_ e: Entity) -> Bool {
    e.type != .bin && e.type != .droplet && e.type != .gearbot && e.type != .climbbot
      && e.type != .flybot && e.type != .eyebot
  }
  func isNotDropletOrJunkbot(_ e: Entity) -> Bool { e.type != .droplet && e.type != .junkbot }

  // MARK: - Rectangle queries

  /// The first entity satisfying `filter` that overlaps the given rectangle (level bounds checked
  /// first), skipping `grabbed` entities and the entity at index `excluding`, or `nil` if none.
  func rectangleCollisionTest(
    x: Int32, y: Int32, width: Int32, height: Int32,
    filter: (Entity) -> Bool,
    excluding: Int = -1
  ) -> Entity? {
    if let bounds = rectangleLevelBoundsCollision(x: x, y: y, width: width, height: height),
      filter(bounds)
    {
      return bounds
    }
    for i in 0..<entities.count {
      let e = entities[i]
      if i == excluding { continue }
      if e.grabbed { continue }
      if !filter(e) { continue }
      if rectanglesIntersect(x, y, width, height, e.x, e.y, e.width, e.height) {
        return e
      }
    }
    return nil
  }

  /// Every entity satisfying `filter` that overlaps the given rectangle (paired with its index;
  /// the synthetic level-bounds hit, if any, uses index `-1`), skipping `grabbed` entities and the
  /// entity at index `excluding`.
  func rectangleCollisionAll(
    x: Int32, y: Int32, width: Int32, height: Int32,
    filter: (Entity) -> Bool,
    excluding: Int = -1
  ) -> [(entity: Entity, index: Int)] {
    var result: [(entity: Entity, index: Int)] = []
    if let bounds = rectangleLevelBoundsCollision(x: x, y: y, width: width, height: height),
      filter(bounds)
    {
      result.append((entity: bounds, index: -1))
    }
    for i in 0..<entities.count {
      let e = entities[i]
      if i == excluding { continue }
      if e.grabbed { continue }
      if !filter(e) { continue }
      if rectanglesIntersect(x, y, width, height, e.x, e.y, e.width, e.height) {
        result.append((entity: e, index: i))
      }
    }
    return result
  }

  // MARK: - Entity-relative queries
  // Like the rectangle queries above, but sized to match an existing entity (`entityIndex`) and
  // automatically excluding it from its own results — the common case of "would entity N collide
  // with anything if moved to (entityX, entityY)?".

  func entityCollisionTest(
    entityX: Int32, entityY: Int32, entityIndex: Int,
    filter: (Entity) -> Bool
  ) -> Entity? {
    let e = entities[entityIndex]
    return rectangleCollisionTest(
      x: entityX, y: entityY, width: e.width, height: e.height,
      filter: { other in other.id != e.id && filter(other) },
      excluding: entityIndex
    )
  }

  func entityCollisionAll(
    entityX: Int32, entityY: Int32, entityIndex: Int,
    filter: (Entity) -> Bool
  ) -> [(entity: Entity, index: Int)] {
    let e = entities[entityIndex]
    return rectangleCollisionAll(
      x: entityX, y: entityY, width: e.width, height: e.height,
      filter: { other in other.id != e.id && filter(other) },
      excluding: entityIndex
    )
  }

  /// Steps a `width`×`height` probe one grid cell at a time from `(startX, startY)` in direction
  /// `(directionX, directionY)`, up to `maxSteps`, stopping at the first entity satisfying
  /// `filter` (or the level bounds). Used by `eyebot` targeting and `laser` beams (`Simulation.swift`).
  func raycast(
    startX: Int32, startY: Int32,
    width: Int32, height: Int32,
    directionX: Int32, directionY: Int32,
    maxSteps: Int32,
    filter: (Entity) -> Bool
  ) -> RaycastHit {
    var x = startX
    var y = startY
    for step in 0..<maxSteps {
      x += CELL_W * directionX
      y += CELL_H * directionY
      if let bounds = rectangleLevelBoundsCollision(x: x, y: y, width: width, height: height),
        filter(bounds)
      {
        return RaycastHit(steps: step, entity: bounds, entityIndex: -1)
      }
      for i in 0..<entities.count {
        let e = entities[i]
        if e.grabbed { continue }
        if !filter(e) { continue }
        if rectanglesIntersect(x, y, width, height, e.x, e.y, e.width, e.height) {
          return RaycastHit(steps: step, entity: e, entityIndex: i)
        }
      }
    }
    return RaycastHit(steps: maxSteps, entity: nil, entityIndex: -1)
  }

  // MARK: - Acceleration structures
  // `entitiesByTopY`/`entitiesByBottomY` map a y-coordinate to the entities whose top/bottom edge
  // sits there, so "what's directly above/below this position" (used heavily by simulation and
  // `connectsToFixed` below) doesn't need to scan every entity.

  /// Registers entity `index`'s current position in the acceleration structures. Must be called
  /// whenever an entity's `y`/`height` changes; does not remove stale entries for its old position
  /// (see `rebuildAccelerationStructures`, which is used instead whenever positions may have moved).
  func entityMoved(index: Int) {
    let e = entities[index]
    let topY = e.y
    let bottomY = e.y + e.height
    if var arr = entitiesByTopY[topY] {
      if !arr.contains(index) {
        arr.append(index)
        entitiesByTopY[topY] = arr
      }
    } else {
      entitiesByTopY[topY] = [index]
    }
    if var arr = entitiesByBottomY[bottomY] {
      if !arr.contains(index) {
        arr.append(index)
        entitiesByBottomY[bottomY] = arr
      }
    } else {
      entitiesByBottomY[bottomY] = [index]
    }
  }

  /// Clears and fully rebuilds `entitiesByTopY`/`entitiesByBottomY` from the current `entities`
  /// array. Called once per tick (and after any bulk entity replacement), since incremental
  /// updates via `entityMoved` can't account for entities being added, removed, or repositioned
  /// out from under a stale index.
  func rebuildAccelerationStructures() {
    entitiesByTopY.removeAll(keepingCapacity: true)
    entitiesByBottomY.removeAll(keepingCapacity: true)
    for i in 0..<entities.count {
      entityMoved(index: i)
    }
  }

  /// Whether entity `startIndex` is transitively supported by a `fixed` entity (or the level
  /// floor), following the stack of things resting directly on top of / underneath it via the
  /// acceleration structures. Used to decide whether a group of bricks can be lifted as a unit
  /// (if not connected to anything fixed) or would collapse a structure if moved (if it is).
  ///
  /// - Parameters:
  ///   - direction: Restricts which side of the *starting* entity is searched: `1` searches only
  ///     upward from it, `-1` only downward, `0` (default) both. Entities reached transitively
  ///     from there are always searched in both directions regardless of this value.
  ///   - ignoreIndices: Entities to treat as if they weren't there (e.g. the rest of the group
  ///     already being dragged, so it doesn't "support itself").
  func connectsToFixed(startIndex: Int, direction: Int32 = 0, ignoreIndices: [Int] = []) -> Bool {
    if let bounds = levelBounds {
      let e = entities[startIndex]
      if e.y + e.height >= bounds.y + bounds.height { return true }
    }
    var visited: [Int] = [startIndex]

    func search(fromIndex: Int) -> Bool {
      let from = entities[fromIndex]
      if let bounds = levelBounds, from.y + from.height >= bounds.y + bounds.height { return true }
      let above = entitiesByTopY[from.y + from.height] ?? []
      let below = entitiesByBottomY[from.y] ?? []
      var candidates: [Int] = []
      if fromIndex != startIndex || direction != -1 { candidates += above }
      if fromIndex != startIndex || direction != 1 { candidates += below }
      for otherIdx in candidates {
        if ignoreIndices.contains(otherIdx) { continue }
        if visited.contains(otherIdx) { continue }
        let other = entities[otherIdx]
        if other.grabbed { continue }
        guard from.x + from.width > other.x && from.x < other.x + other.width else { continue }
        visited.append(otherIdx)
        if other.fixed { return true }
        if search(fromIndex: otherIdx) { return true }
      }
      return false
    }

    return search(fromIndex: startIndex)
  }
}
