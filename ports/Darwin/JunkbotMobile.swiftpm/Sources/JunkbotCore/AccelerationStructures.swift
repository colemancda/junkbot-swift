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

/// Groups indices of `extents` by their top and bottom y-coordinates. The two resulting maps are
/// `GameEngine`'s `entitiesByTopY`/`entitiesByBottomY` acceleration structures, used to look up
/// what's directly above/below a given y without scanning every entity (see `Collision.swift`).
public func groupIndicesByY(_ extents: [YExtent]) -> (byTop: [Int32: [Int]], byBottom: [Int32: [Int]]) {
  var byTop: [Int32: [Int]] = [:]
  var byBottom: [Int32: [Int]] = [:]
  for (i, e) in extents.enumerated() {
    // Not `byTop[e.top, default: []].append(i)`: that shorthand's `default: []` is a fresh
    // zero-capacity array literal every time a key is first seen, so a second entity sharing
    // the same top/bottom y (e.g. a row of bricks resting on the same floor) immediately grows
    // it past capacity. Reserve a small amount up front instead, so sharing a y-coordinate with
    // a handful of other entities (the common case) never needs to reallocate. See
    // GameEngine.init()'s reserve comment for why growth-without-reserve matters on ports/PS1.
    if byTop[e.top] == nil {
      var bucket: [Int] = []
      bucket.reserveCapacity(8)
      byTop[e.top] = bucket
    }
    byTop[e.top]!.append(i)
    if byBottom[e.bottom] == nil {
      var bucket: [Int] = []
      bucket.reserveCapacity(8)
      byBottom[e.bottom] = bucket
    }
    byBottom[e.bottom]!.append(i)
  }
  return (byTop, byBottom)
}
