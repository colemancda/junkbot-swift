//
//  Rect.swift
//  Junkbot
//
//  Created by Alsey Coleman Miller on 7/1/26.
//

public struct Rect: Equatable, @unchecked Sendable {
  public var x, y, width, height: Int
  public init(x: Int, y: Int, width: Int, height: Int) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  public func contains(_ point: Point) -> Bool {
    point.x >= x && point.y >= y && point.x < x + width && point.y < y + height
  }
}
