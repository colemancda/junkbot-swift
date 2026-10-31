import JunkbotBackend

// The Core Graphics geometry types, as plain Swift values. They become
// floats only when passed to the backend.

public typealias CGFloat = Double

public struct CGPoint: Equatable {
    public var x: CGFloat
    public var y: CGFloat

    public static let zero = CGPoint(x: 0, y: 0)

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

public struct CGSize: Equatable {
    public var width: CGFloat
    public var height: CGFloat

    public static let zero = CGSize(width: 0, height: 0)

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}

public struct CGRect: Equatable {
    public var origin: CGPoint
    public var size: CGSize

    public init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }
}

public final class CGMutablePath: _BackendObject {
    public init() {
        super.init(retained: jb_path_create())
    }

    public func move(to point: CGPoint) {
        jb_path_move(pointer, _bits(point.x), _bits(point.y))
    }

    public func addLine(to point: CGPoint) {
        jb_path_add_line(pointer, _bits(point.x), _bits(point.y))
    }

    public func closeSubpath() {
        jb_path_close(pointer)
    }
}

/// A float passed to the backend as its bit pattern; see `JunkbotBackend.h`.
public func _bits(_ value: CGFloat) -> UInt {
    UInt(Float(value).bitPattern)
}
