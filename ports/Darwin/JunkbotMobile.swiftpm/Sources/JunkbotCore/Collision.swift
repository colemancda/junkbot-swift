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
    for i in gridCandidateIndices(x: x, y: y, width: width, height: height) {
      // The grid can briefly hold indices from before an `entities.removeAll` shrank the array
      // (fixed at its known call sites by rebuilding right after - see `simulate()` - but this
      // guard is a cheap backstop against any other gap): an out-of-range index is always just
      // stale, never a real entity to report, so skip rather than crash.
      guard i < entities.count else { continue }
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
    for i in gridCandidateIndices(x: x, y: y, width: width, height: height) {
      // See the matching guard in `rectangleCollisionTest` above.
      guard i < entities.count else { continue }
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
      for i in gridCandidateIndices(x: x, y: y, width: width, height: height) {
        // See the matching guard in `rectangleCollisionTest`.
        guard i < entities.count else { continue }
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

  /// Inserts `index` into `sortedByY` at the position keeping it sorted by `.y`, unless an entry
  /// for the same `(y, index)` pair is already there (mirrors the old `Dictionary` version's
  /// dedup, which skipped re-appending an index already present in that y's bucket).
  private func insertSortedByY(_ sortedByY: inout [(y: Int32, index: Int)], y: Int32, index: Int) {
    let start = lowerBoundByY(sortedByY, y)
    var i = start
    while i < sortedByY.count, sortedByY[i].y == y {
      if sortedByY[i].index == index { return }
      i += 1
    }
    sortedByY.insert((y: y, index: index), at: start)
  }

  /// Registers entity `index`'s current position in the acceleration structures. Must be called
  /// whenever an entity's `x`/`y`/`width`/`height` changes - `x` matters too, not just `y`, since
  /// `collisionGrid` buckets by both axes (a real bug once: `simulateJunkbot`'s crate-push moved
  /// `entities[crate.index].x` without a matching call, so a just-pushed crate's *new* position was
  /// never inserted into the grid - only its stale pre-push cell - causing collisions with it to
  /// go undetected for the rest of that tick). Does not remove stale entries for its old position
  /// (see `rebuildAccelerationStructures`, which is used instead whenever positions may have moved).
  /// Callers that read these structures must re-validate the match against the live entity (as
  /// `connectsToFixed` does) rather than trusting a looked-up index unconditionally, since a stale
  /// entry can still be present under an entity's old y (or old grid cells).
  func entityMoved(index: Int) {
    let e = entities[index]
    insertSortedByY(&entitiesByTopY, y: e.y, index: index)
    insertSortedByY(&entitiesByBottomY, y: e.y + e.height, index: index)
    insertIntoGrid(index: index)
  }

  /// Clears and fully rebuilds `entitiesByTopY`/`entitiesByBottomY`/`collisionGrid` from the
  /// current `entities` array. Called once per tick (and after any bulk entity replacement), since
  /// incremental updates via `entityMoved` can't account for entities being added, removed, or
  /// repositioned out from under a stale index.
  func rebuildAccelerationStructures() {
    entitiesByTopY.removeAll(keepingCapacity: true)
    entitiesByBottomY.removeAll(keepingCapacity: true)
    rebuildCollisionGrid()
    for i in 0..<entities.count {
      entityMoved(index: i)
    }
  }

  // MARK: - Collision grid
  // `collisionGrid` (declared in `GameEngine.swift`) buckets entities by which CELL_W x CELL_H
  // grid cells their bounding box overlaps, so `rectangleCollisionTest`/`rectangleCollisionAll`/
  // `raycast` only need to check entities near a query rectangle instead of every entity on the
  // level. Correctness never depends on the grid being precise: every candidate it returns is
  // re-validated with the exact `rectanglesIntersect` test by the caller (same "hint, not fact"
  // principle as `entitiesByTopY`/`entitiesByBottomY` above), so clamping a wildly out-of-bounds
  // position into an edge cell can only add harmless extra candidates, never cause a missed hit -
  // an entity that's also that far out would be clamped into the exact same edge cell, and the
  // real (unclamped) coordinates still decide whether they actually intersect.

  /// Floor division for a positive `cellSize`, unlike Swift's `/` (which truncates toward zero) -
  /// needed so a negative `value` (a query/entity position left or above the grid's origin) maps
  /// to the correct cell instead of off-by-one toward zero.
  private func floorDivCell(_ value: Int32, _ cellSize: Int32) -> Int32 {
    value >= 0 ? value / cellSize : (value - cellSize + 1) / cellSize
  }

  private func clampCell(_ value: Int32, _ count: Int32) -> Int32 {
    min(max(value, 0), max(count - 1, 0))
  }

  /// Recomputes the grid's dimensions from `levelBounds` (padded by a few cells, since raycast
  /// probes and teleport/laser checks can land slightly outside the level) and clears it. Leaves
  /// the grid empty (`collisionGridCols == 0`) when there's no `levelBounds` - `gridCandidateIndices`
  /// falls back to scanning every entity in that case, matching the pre-grid behavior exactly for
  /// that (unshipped, editor-only) scenario.
  private func rebuildCollisionGrid() {
    guard let bounds = levelBounds else {
      collisionGrid = []
      collisionGridCols = 0
      collisionGridRows = 0
      return
    }
    let padding: Int32 = 4
    collisionGridOriginX = bounds.x - padding * CELL_W
    collisionGridOriginY = bounds.y - padding * CELL_H
    let totalWidth = bounds.width + 2 * padding * CELL_W
    let totalHeight = bounds.height + 2 * padding * CELL_H
    collisionGridCols = max((totalWidth + CELL_W - 1) / CELL_W, 1)
    collisionGridRows = max((totalHeight + CELL_H - 1) / CELL_H, 1)
    collisionGrid = Array(repeating: [], count: Int(collisionGridCols) * Int(collisionGridRows))
  }

  /// Shared by `insertIntoGrid`/`gridCandidateIndices`: the inclusive `(colStart, colEnd, rowStart,
  /// rowEnd)` grid-cell range a `(x, y, width, height)` rectangle overlaps, clamped to the grid's
  /// bounds. Factored out (rather than duplicated at both call sites) to keep this embedded-target
  /// code's compiled size down - every port shares this file, including code-size-constrained ones.
  private func gridCellRange(x: Int32, y: Int32, width: Int32, height: Int32) -> (
    colStart: Int32, colEnd: Int32, rowStart: Int32, rowEnd: Int32
  ) {
    (
      colStart: clampCell(floorDivCell(x - collisionGridOriginX, CELL_W), collisionGridCols),
      colEnd: clampCell(floorDivCell(x + width - 1 - collisionGridOriginX, CELL_W), collisionGridCols),
      rowStart: clampCell(floorDivCell(y - collisionGridOriginY, CELL_H), collisionGridRows),
      rowEnd: clampCell(floorDivCell(y + height - 1 - collisionGridOriginY, CELL_H), collisionGridRows)
    )
  }

  /// Adds `index` to every grid cell its current bounding box overlaps. No-op if the grid is empty
  /// (no `levelBounds`).
  private func insertIntoGrid(index: Int) {
    guard collisionGridCols > 0, collisionGridRows > 0 else { return }
    let e = entities[index]
    let range = gridCellRange(x: e.x, y: e.y, width: e.width, height: e.height)
    guard range.colStart <= range.colEnd, range.rowStart <= range.rowEnd else { return }
    var row = range.rowStart
    while row <= range.rowEnd {
      var col = range.colStart
      while col <= range.colEnd {
        let cellIndex = Int(row) * Int(collisionGridCols) + Int(col)
        if !collisionGrid[cellIndex].contains(index) {
          collisionGrid[cellIndex].append(index)
        }
        col += 1
      }
      row += 1
    }
  }

  /// Every entity index whose grid cells overlap the query rectangle, deduplicated and returned in
  /// ascending order (so callers that care about "first match by index" - e.g.
  /// `rectangleCollisionTest`'s single-result search - see the same candidate order the old
  /// brute-force `for i in 0..<entities.count` scan would have). Falls back to every entity index
  /// (in order) when the grid is empty (no `levelBounds`).
  func gridCandidateIndices(x: Int32, y: Int32, width: Int32, height: Int32) -> [Int] {
    guard collisionGridCols > 0, collisionGridRows > 0 else {
      return Array(0..<entities.count)
    }
    let range = gridCellRange(x: x, y: y, width: width, height: height)
    guard range.colStart <= range.colEnd, range.rowStart <= range.rowEnd else { return [] }
    var seen: Set<Int> = []
    var result: [Int] = []
    var row = range.rowStart
    while row <= range.rowEnd {
      var col = range.colStart
      while col <= range.colEnd {
        let cellIndex = Int(row) * Int(collisionGridCols) + Int(col)
        for idx in collisionGrid[cellIndex] where seen.insert(idx).inserted {
          result.append(idx)
        }
        col += 1
      }
      row += 1
    }
    result.sort()
    return result
  }

  /// Every index in `sortedByY` whose `y` exactly matches `target` (a contiguous run, since the
  /// array is sorted by `y`) - the candidate set for "what's directly above/below this position",
  /// far smaller than every entity on a busy level.
  private func indices(in sortedByY: [(y: Int32, index: Int)], atY target: Int32) -> ArraySlice<
    (y: Int32, index: Int)
  > {
    let start = lowerBoundByY(sortedByY, target)
    var end = start
    while end < sortedByY.count, sortedByY[end].y == target { end += 1 }
    return sortedByY[start..<end]
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
    var visited: Set<Int> = []

    // Candidates come from `entitiesByTopY`/`entitiesByBottomY` (narrowed to the handful of
    // entities actually at the relevant y, not every entity on the level), but every candidate is
    // still re-validated below (isBelow/isAbove, x-overlap) exactly as the old brute-force scan
    // did - the acceleration structures can hold stale entries for an entity's old position (see
    // `entityMoved`'s doc comment), so a candidate is a hint to check, never a fact to trust.
    func candidates(from: Entity, includeBelow: Bool, includeAbove: Bool) -> [Int] {
      var result: [Int] = []
      if includeBelow {
        for entry in indices(in: entitiesByTopY, atY: from.y + from.height) {
          result.append(entry.index)
        }
      }
      if includeAbove {
        for entry in indices(in: entitiesByBottomY, atY: from.y) {
          result.append(entry.index)
        }
      }
      return result
    }

    func search(fromIndex: Int) -> Bool {
      let from = entities[fromIndex]
      if let bounds = levelBounds, from.y + from.height >= bounds.y + bounds.height { return true }
      // `direction` only restricts which side is searched from `startIndex` itself; once the
      // search moves on to a neighbor, both sides are always considered (matches the original
      // JS `connectsToFixed`).
      let includeBelow = fromIndex != startIndex || direction != -1
      let includeAbove = fromIndex != startIndex || direction != 1
      for otherIdx in candidates(from: from, includeBelow: includeBelow, includeAbove: includeAbove) {
        guard otherIdx != fromIndex else { continue }
        let other = entities[otherIdx]
        let isBelow = other.y == from.y + from.height  // other's top touches from's bottom
        let isAbove = other.y + other.height == from.y  // other's bottom touches from's top
        guard (isBelow && includeBelow) || (isAbove && includeAbove) else { continue }
        if ignoreIndices.contains(otherIdx) { continue }
        if visited.contains(otherIdx) { continue }
        if other.grabbed { continue }
        guard from.x + from.width > other.x && from.x < other.x + other.width else { continue }
        visited.insert(otherIdx)
        if other.fixed { return true }
        if search(fromIndex: otherIdx) { return true }
      }
      return false
    }

    return search(fromIndex: startIndex)
  }

  /// Whether entity `b` is directly adjacent to entity `a` on the given vertical side, with some
  /// horizontal overlap: `direction == 1` requires `b` directly below `a` (touching `a`'s bottom
  /// edge), `direction == -1` requires `b` directly above `a` (touching `a`'s top edge), and the
  /// default `0` accepts either side. Index-based counterpart of `main.swift`'s `entitiesConnect`
  /// (which operates on JSObjects for the WASM bridge).
  func connects(_ aIndex: Int, _ bIndex: Int, direction: Int32 = 0) -> Bool {
    let a = entities[aIndex], b = entities[bIndex]
    return ((direction >= 0 && b.y == a.y + a.height) || (direction <= 0 && b.y + b.height == a.y))
      && a.x + a.width > b.x && a.x < b.x + b.width
  }

  /// Every entity transitively resting on/under a `fixed` entity, found by breadth-first search
  /// from each `fixed` entity outward along vertical adjacency (`connects`, either direction).
  /// Index-based counterpart of `main.swift`'s `allConnectedToFixedExport`; like that function,
  /// deliberately does not exclude `grabbed` entities from the traversal itself (only callers that
  /// separately check `!grabbed` exclude them) — matches the original JS behavior exactly.
  ///
  /// The visited set is a `Set<Int>`, not `[Int]`: this function is recomputed every frame while
  /// dragging (`canRelease()`, called from `RenderList.swift`'s `buildRenderFrame`), and an
  /// `Array.contains` membership check inside a full-entity scan made the whole traversal scale
  /// worse than quadratically (confirmed empirically - see DragPerformanceTests.swift - 200
  /// entities took 534x longer than 20, not the ~10x linear scaling this should have). `Set`
  /// membership is O(1), leaving the unavoidable per-node "scan every entity for vertical
  /// adjacency" cost (still O(n) per visited node, since `entitiesByTopY`/`entitiesByBottomY`
  /// aren't consulted here despite existing for exactly this query - a further optimization left
  /// for later, since it'd need care to preserve the x-overlap check these dictionaries don't
  /// capture on their own).
  func allConnectedToFixed() -> [Int] {
    var connected: Set<Int> = []
    func addAnyAttached(_ index: Int) {
      let e = entities[index]
      for other in 0..<entities.count {
        guard other != index, !connected.contains(other) else { continue }
        let o = entities[other]
        guard e.x + e.width > o.x && e.x < o.x + o.width else { continue }
        guard o.y + o.height == e.y || e.y + e.height == o.y else { continue }
        connected.insert(other)
        addAnyAttached(other)
      }
    }
    for i in 0..<entities.count where entities[i].fixed {
      guard !connected.contains(i) else { continue }
      connected.insert(i)
      addAnyAttached(i)
    }
    return Array(connected)
  }
}
