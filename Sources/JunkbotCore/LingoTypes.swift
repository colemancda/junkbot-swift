// LingoTypes.swift
// Shared value types replacing Lingo's dynamic Any/prop-list system.

// MARK: - Point

public struct Point: Equatable {
    public var x: Int
    public var y: Int
    public init(x: Int = 0, y: Int = 0) { self.x = x; self.y = y }
    public static func + (l: Point, r: Point) -> Point { Point(x: l.x + r.x, y: l.y + r.y) }
    public static func - (l: Point, r: Point) -> Point { Point(x: l.x - r.x, y: l.y - r.y) }
    public static func * (l: Point, r: Point) -> Point { Point(x: l.x * r.x, y: l.y * r.y) }
    public static func / (l: Point, r: Point) -> Point { Point(x: l.x / r.x, y: l.y / r.y) }
    public static prefix func - (p: Point) -> Point { Point(x: -p.x, y: -p.y) }
    public func offset(dx: Int, dy: Int) -> Point { Point(x: x + dx, y: y + dy) }
}

// MARK: - LV (LingoValue) — replaces Any in all dynamic Lingo contexts

/// PropList: ordered key-value store mapping String keys to LV values.
/// Mirrors Lingo's property list [:] type. Uses a class so it can be stored
/// in LV without making LV recursive (no indirect enum needed).
public final class PropList {
    public var props: [(key: String, value: LV)]
    public init(_ props: [(key: String, value: LV)] = []) { self.props = props }

    public subscript(key: String) -> LV {
        get { props.first(where: { $0.key == key })?.value ?? .void }
        set {
            if let i = props.firstIndex(where: { $0.key == key }) {
                props[i] = (key, newValue)
            } else {
                props.append((key, newValue))
            }
        }
    }
    public var count: Int { props.count }
    public func getPropAt(_ i: Int) -> String { props[i - 1].key }  // 1-based
    public func addProp(_ key: String, _ value: LV) { props.append((key, value)) }
    public func deleteOne(_ key: String) {
        if let i = props.firstIndex(where: { $0.key == key }) { props.remove(at: i) }
    }
    public func duplicate() -> PropList {
        let p = PropList(props)
        return p
    }
    public var isEmpty: Bool { props.isEmpty }
}

/// LingoList: ordered dynamic list — mirrors Lingo's [] list type.
public final class LingoList {
    public var items: [LV]
    public init(_ items: [LV] = []) { self.items = items }
    public var count: Int { items.count }
    public func add(_ v: LV) { items.append(v) }
    // 1-based index matching Lingo
    public subscript(i: Int) -> LV {
        get { items[i - 1] }
        set { items[i - 1] = newValue }
    }
    public func getOne(_ v: LV) -> Bool {
        for item in items {
            if item == v { return true }
        }
        return false
    }
    public func deleteOne(_ v: LV) {
        for i in 0..<items.count {
            if items[i] == v { items.remove(at: i); return }
        }
    }
    public func deleteAt(_ i: Int) { items.remove(at: i - 1) }  // 1-based
    public func duplicate() -> LingoList { LingoList(items) }
    public var isEmpty: Bool { items.isEmpty }
}

/// LV: the universal Lingo value type. Replaces Any/AnyObject throughout.
public enum LV {
    case void
    case int(Int)
    case float(Float)
    case string(String)
    case point(x: Int, y: Int)
    case list(LingoList)
    case propList(PropList)
    case object(LingoObject)  // typed object reference (no AnyObject in Embedded Swift)

    // MARK: Accessors
    public var asInt: Int? {
        switch self {
        case .int(let n): return n
        case .string(let s): return Int(s)
        default: return nil
        }
    }
    public var asFloat: Float? {
        if case .float(let f) = self { return f }
        if case .int(let n) = self { return Float(n) }
        return nil
    }
    public var asString: String? {
        switch self {
        case .string(let s): return s
        case .int(let n): return String(n)
        case .float(let f): return String(f)
        case .void: return nil
        default: return nil
        }
    }
    public var asPropList: PropList? {
        if case .propList(let p) = self { return p }
        return nil
    }
    public var asList: LingoList? {
        if case .list(let l) = self { return l }
        return nil
    }
    public var asPoint: Point? {
        if case .point(let x, let y) = self { return Point(x: x, y: y) }
        return nil
    }
    public func asObject() -> LingoObject? {
        if case .object(let o) = self { return o }
        return nil
    }
    public var isVoid: Bool {
        if case .void = self { return true }
        return false
    }
    public var isList: Bool {
        if case .list = self { return true }
        return false
    }
    public var isPropList: Bool {
        if case .propList = self { return true }
        return false
    }
    public var isString: Bool {
        if case .string = self { return true }
        return false
    }

    public static func == (l: LV, r: LV) -> Bool {
        switch (l, r) {
        case (.void, .void): return true
        case (.int(let a), .int(let b)): return a == b
        case (.float(let a), .float(let b)): return a == b
        case (.string(let a), .string(let b)): return a == b
        case (.point(let ax, let ay), .point(let bx, let by)): return ax == bx && ay == by
        case (.list(let a), .list(let b)): return a === b
        case (.propList(let a), .propList(let b)): return a === b
        case (.object(let a), .object(let b)): return a === b
        default: return false
        }
    }
}

// Convenience constructors
extension LV {
    public static func sym(_ s: String) -> LV { .string(s) }
    public static func pt(_ x: Int, _ y: Int) -> LV { .point(x: x, y: y) }
    public static var emptyList: LV { .list(LingoList()) }
    public static var emptyPropList: LV { .propList(PropList()) }
}

// MARK: - LingoObject — base class for any object stored in an LV value
/// Embedded Swift has no AnyObject. Subclass LingoObject to store class
/// references inside LV.object(_:).
public class LingoObject {
    public init() {}
}

// MARK: - BehaviorBase (base for behavior script objects stored on sprites)
public class BehaviorBase: LingoObject {
    public override init() { super.init() }
    public func stepFrame() {}
    public func notify(_ notes: PropList) {}
}

// MARK: - Global state
/// Replaces Lingo's `global glob` — a dynamic property bag for cross-module state.
public final class Glob {
    public static let shared = Glob()
    private var data: PropList = PropList()
    public subscript(key: String) -> LV {
        get { data[key] }
        set { data[key] = newValue }
    }
    private init() {}
}
