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
