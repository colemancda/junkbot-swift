public struct YExtent: Sendable {
  public var top, bottom: Int32
  public init(top: Int32, bottom: Int32) {
    self.top = top
    self.bottom = bottom
  }
}

/// Groups indices of `extents` by their top and bottom y-coordinates.
public func groupIndicesByY(_ extents: [YExtent]) -> (byTop: [Int32: [Int]], byBottom: [Int32: [Int]]) {
  var byTop: [Int32: [Int]] = [:]
  var byBottom: [Int32: [Int]] = [:]
  for (i, e) in extents.enumerated() {
    byTop[e.top, default: []].append(i)
    byBottom[e.bottom, default: []].append(i)
  }
  return (byTop, byBottom)
}
