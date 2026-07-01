public struct RenderBox: Sendable {
  public var x, y, width, height: Double
  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
}

/// Returns the indices of `boxes` in painter's-algorithm rendering order.
public func sortOrderForRendering(_ boxes: [RenderBox]) -> [Int] {
  var order = Array(boxes.indices)
  order.sort { boxes[$0].y > boxes[$1].y }

  var n = order.count
  repeat {
    var newN = 0
    if n > 1 {
      for i in 1..<n {
        let a = boxes[order[i - 1]]
        let b = boxes[order[i]]
        if a.y + a.height < b.y || b.x + b.width <= a.x {
          order.swapAt(i - 1, i)
          newN = i
        }
      }
    }
    n = newN
  } while n > 1

  return order
}
