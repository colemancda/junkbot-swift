extension GameEngine {

  func rectanglesIntersect(
    _ ax: Int32, _ ay: Int32, _ aw: Int32, _ ah: Int32,
    _ bx: Int32, _ by: Int32, _ bw: Int32, _ bh: Int32
  ) -> Bool {
    ax + aw > bx && ax < bx + bw && ay + ah > by && ay < by + bh
  }

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

  func isNotDroplet(_ e: Entity) -> Bool { e.type != .droplet }
  func isNotBinOrDroplet(_ e: Entity) -> Bool { e.type != .bin && e.type != .droplet }
  func isNotBinOrDropletOrEnemyBot(_ e: Entity) -> Bool {
    e.type != .bin && e.type != .droplet && e.type != .gearbot && e.type != .climbbot
      && e.type != .flybot && e.type != .eyebot
  }
  func isNotDropletOrJunkbot(_ e: Entity) -> Bool { e.type != .droplet && e.type != .junkbot }

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

  func rebuildAccelerationStructures() {
    entitiesByTopY.removeAll(keepingCapacity: true)
    entitiesByBottomY.removeAll(keepingCapacity: true)
    for i in 0..<entities.count {
      entityMoved(index: i)
    }
  }

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
