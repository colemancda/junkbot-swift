import JunkbotBackend

// The few Foundation APIs the shared game files use, for Embedded Swift,
// which has no Foundation. File URLs are paths; data is bytes.

public typealias TimeInterval = Double

/// A file URL.
public struct URL: Equatable {
    public var path: String

    public init(fileURLWithPath path: String) {
        self.path = path
    }

    /// Only file URLs and paths are supported.
    public init?(string: String) {
        self.path = string
    }

    public var absoluteString: String {
        path
    }

    public func appendingPathComponent(_ component: String) -> URL {
        URL(fileURLWithPath: path.hasSuffix("/") ? path + component : path + "/" + component)
    }

    public func appendingPathComponent(_ component: String, isDirectory: Bool) -> URL {
        appendingPathComponent(component)
    }

    public func deletingLastPathComponent() -> URL {
        guard let slash = path.lastIndex(of: "/") else {
            return URL(fileURLWithPath: ".")
        }
        return URL(fileURLWithPath: String(path[..<slash]))
    }
}

public struct Data: Equatable {
    public var bytes: [UInt8]

    public init() {
        bytes = []
    }

    public init<S: Sequence>(_ elements: S) where S.Element == UInt8 {
        bytes = Array(elements)
    }

    public var count: Int {
        bytes.count
    }
}

public final class FileManager {
    public static let `default` = FileManager()

    public func fileExists(atPath path: String) -> Bool {
        jb_file_exists(path) != 0
    }
}

public final class FileHandle {
    /// Writes to the system log.
    public static let standardError = FileHandle()

    public func write(_ data: Data) {
        data.bytes.withUnsafeBufferPointer {
            jb_log($0.baseAddress, UInt($0.count))
        }
    }
}

public final class Bundle {
    public static let main = Bundle()

    public let bundleURL: URL

    public var resourceURL: URL? {
        bundleURL
    }

    init() {
        let path = jb_resource_path()!
        bundleURL = URL(fileURLWithPath: String(cString: path))
        jb_free(path)
    }
}

public struct DispatchTime {
    public let uptimeNanoseconds: UInt64

    public static func now() -> DispatchTime {
        var nanoseconds: UInt64 = 0
        jb_uptime_nanoseconds(&nanoseconds)
        return DispatchTime(uptimeNanoseconds: nanoseconds)
    }
}
