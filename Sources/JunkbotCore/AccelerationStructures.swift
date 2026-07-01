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
    byTop[e.top, default: []].append(i)
    byBottom[e.bottom, default: []].append(i)
  }
  return (byTop, byBottom)
}
