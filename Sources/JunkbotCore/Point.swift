//
//  Point.swift
//  Junkbot
//
//  Created by Alsey Coleman Miller on 7/1/26.
//

/// A 2D integer point, used by the Lingo/Director compatibility shims in `DirectorStubs.swift`
/// (e.g. `mouseLoc`, `LingoSprite.loc`) rather than by the core game/collision types, which use
/// `Int32` fields on `Entity` directly.
public struct Point: Equatable, @unchecked Sendable {
  public var x: Int
  public var y: Int
  public init(x: Int = 0, y: Int = 0) {
    self.x = x
    self.y = y
  }
  public static func + (l: Point, r: Point) -> Point { Point(x: l.x + r.x, y: l.y + r.y) }
  public static func - (l: Point, r: Point) -> Point { Point(x: l.x - r.x, y: l.y - r.y) }
  public static func * (l: Point, r: Point) -> Point { Point(x: l.x * r.x, y: l.y * r.y) }
  public static func / (l: Point, r: Point) -> Point { Point(x: l.x / r.x, y: l.y / r.y) }
  public static prefix func - (p: Point) -> Point { Point(x: -p.x, y: -p.y) }
  public func offset(dx: Int, dy: Int) -> Point { Point(x: x + dx, y: y + dy) }
}
