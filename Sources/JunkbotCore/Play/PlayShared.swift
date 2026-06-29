// Shared types used across Play translations (Lingo → Swift)

// MARK: - Point
// Corresponds to Lingo's point(x, y). p[1] → p.x, p[2] → p.y.
struct Point: Equatable {
    var x: Int
    var y: Int

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    static func + (lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static prefix func - (p: Point) -> Point {
        Point(x: -p.x, y: -p.y)
    }

    static func * (lhs: Point, rhs: Int) -> Point {
        Point(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

// MARK: - Glob
// Corresponds to the Lingo global `glob` prop list used throughout all scripts.
// Access via Glob.shared["key"] or Glob.shared.key.
class Glob {
    static let shared = Glob()

    private var data: [String: Any?] = [:]

    private init() {}

    subscript(key: String) -> Any? {
        get { data[key] ?? nil }
        set { data[key] = newValue }
    }
}
