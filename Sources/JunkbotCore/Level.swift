// MARK: - Level data model

/// A level file's raw, structured contents (INI-style `.txt` format), as opposed to `GameEngine`'s
/// live `[Entity]` array. This is the level-editor/persistence-facing model: it preserves every
/// field needed to serialize back to text losslessly (see `LevelParse.swift`/`LevelSerialize.swift`
/// for the `init(text:)`/`text` conversions), whereas `GameEngine.entities` only keeps what the
/// simulation itself needs.
public struct Level: Equatable, Sendable {
    public var title: String
    /// The target/"par" move count for scoring purposes; `nil` if the level has none.
    public var par: Int?
    public var hint: String
    public var background: LevelBackground?
    public var playfield: LevelPlayfield
    /// Every placed object in the level, in file order.
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

/// The `[background]` section: the backdrop image plus two independent decal layers.
public struct LevelBackground: Equatable, Sendable {
    /// Name of the backdrop image asset (e.g. "bkg1").
    public var backdrop: String
    /// Decals drawn in front of the backdrop but behind entities.
    public var decals: [LevelDecal]
    /// Decals drawn behind the backdrop (or otherwise further back than `decals`).
    public var backgroundDecals: [LevelDecal]

    public init(backdrop: String, decals: [LevelDecal] = [], backgroundDecals: [LevelDecal] = []) {
        self.backdrop = backdrop
        self.decals = decals
        self.backgroundDecals = backgroundDecals
    }
}

/// A single decorative image placed at a fixed pixel position, purely cosmetic (no gameplay effect).
public struct LevelDecal: Equatable, Sendable {
    public var x: Double
    public var y: Double
    /// Name of the decal image asset (e.g. "arrowur", "safetystrip_horiz").
    public var name: String

    public init(x: Double, y: Double, name: String) {
        self.x = x
        self.y = y
        self.name = name
    }
}

/// The `[playfield]` section: grid dimensions and cell size for this level.
public struct LevelPlayfield: Equatable, Sendable {
    public var columns: Int
    public var rows: Int
    /// Grid cell width in pixels (normally matches `CELL_W`).
    public var spacingX: Int
    /// Grid cell height in pixels (normally matches `CELL_H`).
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

/// The animation/state field from a part entry (field [4] in the raw format). This is a coarser,
/// canonicalized view of the raw string — e.g. both `"on"` and `"none"` (the latter being the JS
/// default animation name) collapse to `.on` — so round-tripping through `PartState` does not
/// always reproduce the exact original text (see `PartState.rawText` in `LevelSerialize.swift`).
public enum PartState: Hashable, Sendable {
    /// Raw value `"0"` or empty — not active / no initial state.
    case none
    /// Raw value `"on"` or `"none"` — active/on.
    case on
    /// Raw value `"off"`.
    case off
    /// Raw value `"inactive"` — present but not yet activated.
    case inactive
    /// Raw value `"dormant"`.
    case dormant
    /// Raw value `"dry"`.
    case dry
    /// Raw value `"walk_r"`.
    case walkRight
    /// Raw value `"walk_l"`.
    case walkLeft
    /// Raw value `"walk_u"`.
    case walkUp
    /// Raw value `"walk_d"`.
    case walkDown
    /// Any raw value not otherwise recognized, preserved verbatim.
    case custom(String)

    /// Parses a raw state string (case-insensitively) into its canonical case.
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

/// One placed object from a level's `[partslist]` section — a brick, hazard, enemy, Junkbot's
/// start position, etc. — in its raw, not-yet-converted-to-`Entity` form.
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

    /// Sets `levelBounds` to the given rectangle and centers the viewport on it.
    func initLevelBounds(x: Int32, y: Int32, width: Int32, height: Int32) {
        levelBounds = LevelBounds(x: x, y: y, width: width, height: height)
        viewportCenterX = x + width / 2
        viewportCenterY = y + height / 2
    }
}
