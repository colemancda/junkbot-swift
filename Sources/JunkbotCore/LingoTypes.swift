// LingoTypes.swift
// Shared value types replacing Lingo's dynamic Any/prop-list system.

// MARK: - Point

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

extension Array where Element == Int {
  public var asPoint: Point? {
    guard count >= 2 else { return nil }
    return Point(x: self[0], y: self[1])
  }
}

// MARK: - LV (LingoValue) — replaces Any in all dynamic Lingo contexts

/// PropList: ordered key-value store mapping String keys to LV values.
/// Mirrors Lingo's property list [:] type. Stored as `indirect` in LV to
/// break the recursive value-type cycle.
@dynamicMemberLookup
public final class PropList: @unchecked Sendable {
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

  public subscript(dynamicMember member: String) -> LV {
    get { self[member] }
    set { self[member] = newValue }
  }
  public var count: Int { props.count }
  public func getPropAt(_ i: Int) -> (String, LV) { props[i - 1] }  // 1-based
  public func addProp(_ key: String, _ value: LV) { props.append((key, value)) }
  public func deleteOne(_ key: String) {
    if let i = props.firstIndex(where: { $0.key == key }) { props.remove(at: i) }
  }
  public func duplicate() -> PropList { PropList(props) }
  public var isEmpty: Bool { props.isEmpty }
}

/// LingoList: ordered dynamic list — mirrors Lingo's [] list type.
public final class LingoList: @unchecked Sendable {
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
      if items[i] == v {
        items.remove(at: i)
        return
      }
    }
  }
  public func deleteAt(_ i: Int) { items.remove(at: i - 1) }  // 1-based
  public func append(_ v: LV) { items.append(v) }
  public func removeAll() { items.removeAll() }
  public func duplicate() -> LingoList { LingoList(items) }
  public var isEmpty: Bool { items.isEmpty }
}

/// LV: the universal Lingo value type. Replaces Any/AnyObject throughout.
@dynamicMemberLookup
@dynamicCallable
public enum LV: @unchecked Sendable {
  case void
  case int(Int)
  case float(Float)
  case string(String)
  case point(x: Int, y: Int)
  case list(LingoList)
  indirect case propList(PropList)
  case object(LingoObject)  // typed object reference (no AnyObject in Embedded Swift)

  public subscript(dynamicMember member: String) -> LV {
    get {
      if case .propList(let p) = self { return p[member] }
      return .void
    }
    set {
      if case .propList(let p) = self {
        p[member] = newValue
      }
    }
  }

  public subscript(key: String) -> LV {
    get { self[dynamicMember: key] }
    set { self[dynamicMember: key] = newValue }
  }

  /// Mutates a PropList entry in-place through the LV.
  /// Use instead of `["key"] = value` (which discards the write).
  public func setProp(_ key: String, _ value: LV) {
    if case .propList(let p) = self {
      p[key] = value
    }
  }

  public func dynamicallyCall(withArguments args: [LV]) -> LV {
    return .void
  }

  public func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, LV>) -> LV {
    return .void
  }
}

extension LV: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
  ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
  public init(stringLiteral value: String) { self = .string(value) }
  public init(integerLiteral value: Int) { self = .int(value) }
  public init(floatLiteral value: Float) { self = .float(value) }
  public init(booleanLiteral value: Bool) { self = .int(value ? 1 : 0) }  // Lingo uses 1/0 for true/false
  public init(arrayLiteral elements: LV...) { self = .list(LingoList(elements)) }
  public init(dictionaryLiteral elements: (String, LV)...) {
    self = .propList(PropList(elements.map { ($0, $1) }))
  }
}

extension LV {
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
  public var asPlayfieldManager: PlayfieldManager? {
    asObject()?.asPlayfieldManager
  }
  public var asPlayManager: PlayManager? {
    asObject()?.asPlayManager
  }
  public var asGameManager: GameManager? {
    asObject()?.asGameManager
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
    case (.propList(let a), .propList(let b)):
      return a.props.count == b.props.count
        && zip(a.props, b.props).allSatisfy { $0.key == $1.key && $0.value == $1.value }
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

// MARK: - Lingo Event Protocols

public protocol FrameEvents {
  func prepareFrame()
  func enterFrame()
  func exitFrame()
  func stepFrame()
}
extension FrameEvents {
  public func prepareFrame() {}
  public func enterFrame() {}
  public func exitFrame() {}
  public func stepFrame() {}
}

public protocol SpriteLifecycleEvents {
  func beginSprite()
  func endSprite()
}
extension SpriteLifecycleEvents {
  public func beginSprite() {}
  public func endSprite() {}
}

public protocol MovieLifecycleEvents {
  func prepareMovie()
  func startMovie()
  func stopMovie()
}
extension MovieLifecycleEvents {
  public func prepareMovie() {}
  public func startMovie() {}
  public func stopMovie() {}
}

public protocol MouseEvents {
  func mouseDown()
  func mouseUp()
  func mouseEnter()
  func mouseLeave()
  func mouseWithin()
  func mouseUpOutside()
}
extension MouseEvents {
  public func mouseDown() {}
  public func mouseUp() {}
  public func mouseEnter() {}
  public func mouseLeave() {}
  public func mouseWithin() {}
  public func mouseUpOutside() {}
}

public protocol KeyboardEvents {
  func keyDown()
  func keyUp()
}
extension KeyboardEvents {
  public func keyDown() {}
  public func keyUp() {}
}

public protocol MiscEvents {
  func idle()
  func timeOut()
}
extension MiscEvents {
  public func idle() {}
  public func timeOut() {}
}

// MARK: - LingoObject — base class for any object stored in an LV value
/// Embedded Swift has no AnyObject. Subclass LingoObject to store class
/// references inside LV.object(_:).
public class LingoObject: FrameEvents, SpriteLifecycleEvents, MovieLifecycleEvents, MouseEvents,
  KeyboardEvents, MiscEvents, @unchecked Sendable
{
  public init() {}
  public func notify(_ notes: PropList) {}

  // Virtual accessors replacing dynamic casting
  public var asSprite: LingoSprite? { nil }
  public var asMember: LingoMember? { nil }
  public var asPlayfieldManager: PlayfieldManager? { nil }
  public var asPlayManager: PlayManager? { nil }
  public var asGameManager: GameManager? { nil }
}

extension String {
  public func replacingOccurrences(of: String, with: String) -> String {
    return self
  }
}

// MARK: - Global state
/// Replaces Lingo's `global glob` — a dynamic property bag for cross-module state.
@dynamicMemberLookup
public final class Glob: @unchecked Sendable {
  public static let shared = Glob()
  private var data: PropList = PropList()
  public subscript(key: String) -> LV {
    get { data[key] }
    set { data[key] = newValue }
  }
  public subscript(dynamicMember member: String) -> LV {
    get { data[member] }
    set { data[member] = newValue }
  }
  private init() {}
}

let globalConfigManager = BehaviorConfigManager()
let globalLegopartsManager = BehaviorLegopartsManager()

extension Glob {
  var config_manager: BehaviorConfigManager { globalConfigManager }
  var legoparts_manager: BehaviorLegopartsManager { globalLegopartsManager }
}
