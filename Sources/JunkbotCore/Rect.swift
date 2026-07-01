//
//  Rect.swift
//  Junkbot
//
//  Created by Alsey Coleman Miller on 7/1/26.
//

/// A 2D integer rectangle, used by the Lingo/Director compatibility shims in `DirectorStubs.swift`
/// rather than by the core game/collision types, which use `Int32` fields on `Entity` directly and
/// free functions like `rectanglesIntersect` in `Collision.swift`.
public struct Rect: Equatable, @unchecked Sendable {
  public var x, y, width, height: Int
  public init(x: Int, y: Int, width: Int, height: Int) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  /// Whether `point` lies within this rectangle (inclusive of the top/left edges, exclusive of
  /// the bottom/right edges).
  public func contains(_ point: Point) -> Bool {
    point.x >= x && point.y >= y && point.x < x + width && point.y < y + height
  }
}
