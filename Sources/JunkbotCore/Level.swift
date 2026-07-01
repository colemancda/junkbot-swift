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

// MARK: - GameEngine level bounds

extension GameEngine {

    func initLevelBounds(x: Int32, y: Int32, width: Int32, height: Int32) {
        levelBounds = LevelBounds(x: x, y: y, width: width, height: height)
        viewportCenterX = x + width / 2
        viewportCenterY = y + height / 2
    }
}
