// MARK: - Level data model

public struct Level: Equatable, Sendable {
    public var title: String
    public var par: Int?
    public var hint: String
    public var background: LevelBackground?
    public var playfield: LevelPlayfield
    public var parts: [LevelPart]

    public init(
        title: String = "",
        par: Int? = nil,
        hint: String = "",
        background: LevelBackground? = nil,
        playfield: LevelPlayfield = LevelPlayfield(),
        parts: [LevelPart] = []
    ) {
        self.title = title
        self.par = par
        self.hint = hint
        self.background = background
        self.playfield = playfield
        self.parts = parts
    }
}

public struct LevelBackground: Equatable, Sendable {
    public var backdrop: String
    public var decals: [LevelDecal]

    public init(backdrop: String, decals: [LevelDecal] = []) {
        self.backdrop = backdrop
        self.decals = decals
    }
}

public struct LevelDecal: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var name: String

    public init(x: Double, y: Double, name: String) {
        self.x = x
        self.y = y
        self.name = name
    }
}

public struct LevelPlayfield: Equatable, Sendable {
    public var columns: Int
    public var rows: Int
    public var spacingX: Int
    public var spacingY: Int
    public var scale: Double

    public init(columns: Int = 35, rows: Int = 22, spacingX: Int = 15, spacingY: Int = 18, scale: Double = 1) {
        self.columns = columns
        self.rows = rows
        self.spacingX = spacingX
        self.spacingY = spacingY
        self.scale = scale
    }

    public var pixelWidth: Int { columns * spacingX }
    public var pixelHeight: Int { rows * spacingY }
}

/// The animation/state field from a part entry (field [4] in the raw format).
public enum PartState: Hashable, Sendable {
    case none       // "0" or empty — not active / no initial state
    case on         // "on" or "none" — active/on
    case off        // "off"
    case inactive   // "inactive" — present but not yet activated
    case dormant    // "dormant"
    case dry        // "DRY"
    case walkRight  // "WALK_R"
    case walkLeft   // "WALK_L"
    case walkUp     // "WALK_U"
    case walkDown   // "WALK_D"
    case custom(String)

    public init(_ raw: String) {
        switch raw.lowercased() {
        case "0", "":
            self = .none
        case "on", "none":
            // "none" is the JS default animation name and maps to the on/active state
            self = .on
        case "off":
            self = .off
        case "inactive":
            self = .inactive
        case "dormant":
            self = .dormant
        case "dry":
            self = .dry
        case "walk_r":
            self = .walkRight
        case "walk_l":
            self = .walkLeft
        case "walk_u":
            self = .walkUp
        case "walk_d":
            self = .walkDown
        default:
            self = .custom(raw)
        }
    }
}

public struct LevelPart: Equatable, Sendable {
    /// 1-based grid column (may be fractional per JS float coercion)
    public var gridX: Double
    /// 1-based grid row (may be fractional per JS float coercion)
    public var gridY: Double
    /// Lowercased type name resolved from the types list (e.g. "brick_04", "haz_slickfan", "minifig")
    public var typeName: String
    /// 0-based color index into the colors list
    public var colorIndex: Int
    /// Lowercased color name resolved from the colors list (e.g. "gray", "blue", "red")
    public var colorName: String
    /// Initial animation/state
    public var state: PartState
    /// Numeric value from field [5] (usually 0 or 1)
    public var value: Int
    /// Object relation ID linking switches to controlled objects (e.g. "switch1"); empty string if none
    public var relationID: String

    public init(
        gridX: Double,
        gridY: Double,
        typeName: String,
        colorIndex: Int,
        colorName: String,
        state: PartState,
        value: Int,
        relationID: String = ""
    ) {
        self.gridX = gridX
        self.gridY = gridY
        self.typeName = typeName
        self.colorIndex = colorIndex
        self.colorName = colorName
        self.state = state
        self.value = value
        self.relationID = relationID
    }
}

// MARK: - Parser

extension Level {

    public init(text: String) {
        // Parse the INI-style text into sections of key=value pairs.
        var sections: [String: [(String, String)]] = [:]
        var sectionName = ""

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed: Substring = line.hasSuffix("\r") ? line.dropLast() : line[...]
            let content = trimmed.drop(while: { $0.isWhitespace })
            if content.isEmpty || content.hasPrefix("#") { continue }

            if content.hasPrefix("[") && content.hasSuffix("]") {
                sectionName = String(content.dropFirst().dropLast())
            } else {
                let kv = content.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = String(kv[0])
                let value = kv.count > 1 ? String(kv[1]) : ""
                sections[sectionName, default: []].append((key, value))
            }
        }

        // [info]
        var title = ""
        var par: Int? = nil
        var hint = ""
        for (key, value) in sections["info"] ?? [] {
            switch key.lowercased() {
            case "title": title = value
            case "par": par = Int(value)
            case "hint": hint = value
            default: break
            }
        }

        // [background]
        var background: LevelBackground? = nil
        if let bgEntries = sections["background"] {
            var backdrop = ""
            var decals: [LevelDecal] = []
            for (key, value) in bgEntries {
                switch key.lowercased() {
                case "backdrop":
                    backdrop = value
                case "decals":
                    for entry in value.split(separator: ",") {
                        let f = entry.split(separator: ";").map(String.init)
                        if f.count >= 3, let x = Double(f[0]), let y = Double(f[1]) {
                            decals.append(LevelDecal(x: x, y: y, name: f[2]))
                        }
                    }
                default: break
                }
            }
            if !backdrop.isEmpty {
                background = LevelBackground(backdrop: backdrop, decals: decals)
            }
        }

        // [playfield]
        var playfield = LevelPlayfield()
        for (key, value) in sections["playfield"] ?? [] {
            switch key.lowercased() {
            case "size":
                let f = value.split(separator: ",").compactMap { Int($0) }
                if f.count == 2 { playfield.columns = f[0]; playfield.rows = f[1] }
            case "spacing":
                let f = value.split(separator: ",").compactMap { Int($0) }
                if f.count == 2 { playfield.spacingX = f[0]; playfield.spacingY = f[1] }
            case "scale":
                if let s = Double(value) { playfield.scale = s }
            default: break
            }
        }

        // [partslist] — types and colors are lookup tables for the indexed part entries.
        var types: [String] = []
        var colors: [String] = []
        var parts: [LevelPart] = []

        for (key, value) in sections["partslist"] ?? [] {
            switch key.lowercased() {
            case "types":
                types.append(contentsOf: value.lowercased().split(separator: ",").map(String.init))
            case "colors":
                colors.append(contentsOf: value.lowercased().split(separator: ",").map(String.init))
            case "parts":
                // Entries are comma-separated; fields within each entry are semicolon-separated:
                // gridX;gridY;typeIndex;colorIndex;state;value[;relationID]
                for entry in value.split(separator: ",", omittingEmptySubsequences: false) {
                    let f = entry.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
                    guard f.count >= 6,
                          let gx = Double(f[0]),
                          let gy = Double(f[1]),
                          let ti = Int(f[2]),
                          let ci = Int(f[3]),
                          ti > 0, ti <= types.count,
                          ci > 0, ci <= colors.count
                    else { continue }

                    parts.append(LevelPart(
                        gridX: gx,
                        gridY: gy,
                        typeName: types[ti - 1],
                        colorIndex: ci - 1,
                        colorName: colors[ci - 1],
                        state: PartState(f[4]),
                        value: Int(f[5]) ?? 0,
                        relationID: f.count > 6 ? f[6] : ""
                    ))
                }
            default: break
            }
        }

        self.title = title
        self.par = par
        self.hint = hint
        self.background = background
        self.playfield = playfield
        self.parts = parts
    }
}

// MARK: - GameEngine level bounds

extension GameEngine {

    func initLevelBounds(x: Int32, y: Int32, width: Int32, height: Int32) {
        levelBounds = LevelBounds(x: x, y: y, width: width, height: height)
        viewportCenterX = x + width / 2
        viewportCenterY = y + height / 2
    }
}
