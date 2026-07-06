/// Returns the index of the first element in `sortedByY` (sorted ascending by `.y`) whose `y` is
/// `>= target`, or `sortedByY.count` if none. Standard binary-search lower-bound, used to find the
/// start of a run of entries sharing a given y-coordinate in `GameEngine.entitiesByTopY`/
/// `entitiesByBottomY` without scanning every entity.
public func lowerBoundByY(_ sortedByY: [(y: Int32, index: Int)], _ target: Int32) -> Int {
  var lo = 0
  var hi = sortedByY.count
  while lo < hi {
    let mid = (lo + hi) / 2
    if sortedByY[mid].y < target {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  return lo
}

/// The vertical span of one entity, as input to `groupIndicesByY`.
public struct YExtent: Sendable {
  /// The entity's top edge y-coordinate (`Entity.y`).
  public var top: Int32
  /// The entity's bottom edge y-coordinate (`Entity.y + Entity.height`).
  public var bottom: Int32
  public init(top: Int32, bottom: Int32) {
    self.top = top
    self.bottom = bottom
  }
}

/// Groups indices of `extents` by their top and bottom y-coordinates, for `ports/Web`'s JS bridge
/// (`rebuildAccelerationStructuresExport` in `ports/Web/Sources/JunkbotWASM/main.swift`), which
/// operates on its own raw-`JSObject` entity representation rather than `GameEngine.entities` - a
/// separate consumer from the native-side `entitiesByTopY`/`entitiesByBottomY` sorted arrays above
/// (`Collision.swift`), so it can't share their binary-search-based structure directly. Built and
/// consumed once per call (not incrementally mutated/queried across many frames the way the native
/// structures are), a much lower-churn usage pattern than the one implicated in the `Dictionary`
/// incident those sorted arrays replaced - see their doc comments in `GameEngine.swift`.
public func groupIndicesByY(_ extents: [YExtent]) -> (byTop: [Int32: [Int]], byBottom: [Int32: [Int]]) {
  var byTop: [Int32: [Int]] = [:]
  var byBottom: [Int32: [Int]] = [:]
  for (i, e) in extents.enumerated() {
    byTop[e.top, default: []].append(i)
    byBottom[e.bottom, default: []].append(i)
  }
  return (byTop, byBottom)
}
