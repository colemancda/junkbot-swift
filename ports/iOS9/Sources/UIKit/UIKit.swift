@_exported import Foundation
import JunkbotBackend

/// An Objective-C object owned through the backend.
open class _BackendObject {
    public let pointer: UnsafeMutableRawPointer

    /// Takes ownership of a retained object.
    public init(retained pointer: UnsafeMutableRawPointer) {
        self.pointer = pointer
    }

    /// Retains an object the caller doesn't own.
    public init(unretained pointer: UnsafeMutableRawPointer) {
        jb_retain(pointer)
        self.pointer = pointer
    }

    deinit {
        jb_release(pointer)
    }
}

/// A color, kept as components until it's passed to the backend.
public final class UIColor {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let clear = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let black = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
    public static let white = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
}

public final class UIImage: _BackendObject {
    public init?(contentsOfFile path: String) {
        guard let image = jb_image_create(path) else {
            return nil
        }
        super.init(retained: image)
    }
}

public final class UITouch: _BackendObject, Hashable {
    public static func == (lhs: UITouch, rhs: UITouch) -> Bool {
        lhs.pointer == rhs.pointer
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pointer)
    }
}

public final class UIEvent: _BackendObject {}

public final class UIApplication {
    public static let shared = UIApplication()

    public func open(_ url: URL) {
        jb_open_url(url.absoluteString)
    }
}
