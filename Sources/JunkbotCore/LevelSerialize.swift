#if canImport(Foundation)
import Foundation

extension PartState {
    /// The canonical raw text for this state (inverse of `PartState.init(_:)`). Note this isn't
    /// always byte-identical to whatever the original file contained (e.g. both "on" and "none"
    /// parse to `.on`; this always emits "on"), matching how the original JS's `serializeLevel`
    /// re-derives the animation name from live state rather than preserving original file text.
    var rawText: String {
        switch self {
        case .none: return ""
        case .on: return "on"
        case .off: return "off"
        case .inactive: return "inactive"
        case .dormant: return "dormant"
        case .dry: return "dry"
        case .walkRight: return "walk_r"
        case .walkLeft: return "walk_l"
        case .walkUp: return "walk_u"
        case .walkDown: return "walk_d"
        case .custom(let raw): return raw
        }
    }
}

/// Formats a Double the way JS's Number#toString does for values used in this file format:
/// whole numbers print without a trailing ".0", fractional values print their shortest
/// round-trippable representation (level part coordinates can be fractional, e.g.
/// "13.666666666666666" — see LevelParse.swift).
func formatJSNumber(_ value: Double) -> String {
    if value == value.rounded() && abs(value) < 1e15 {
        return String(Int64(value))
    }
    return String(value)
}

/// Fixed canonical color list (matches JS's `brickColorNames`); unlike `types`, the colors list
/// in a level file is always this full fixed set, never deduped down to just the colors in use.
let brickColorNames = ["white", "red", "green", "blue", "yellow", "gray"]

extension Level {

    /// Serializes this level back to the INI-style level-text format (inverse of
    /// `Level.init(text:)`), mirroring the original JS's `serializeLevel`.
    public var text: String {
        var types: [String] = []
        let colors = brickColorNames
        var partLines: [String] = []

        for part in parts {
            if !types.contains(part.typeName) {
                types.append(part.typeName)
            }
            let typeIndex = (types.firstIndex(of: part.typeName) ?? 0) + 1
            let colorIndex = (colors.firstIndex(of: part.colorName) ?? 0) + 1
            partLines.append(
                "\(formatJSNumber(part.gridX));\(formatJSNumber(part.gridY));\(typeIndex);\(colorIndex);"
                    + "\(part.state.rawText);\(part.value);\(part.relationID)")
        }

        func decalsText(_ decals: [LevelDecal]) -> String {
            decals.map { "\(formatJSNumber($0.x));\(formatJSNumber($0.y));\($0.name)" }.joined(separator: ",")
        }

        var lines: [String] = []
        lines.append("[info]")
        lines.append("title=\(title.isEmpty ? "Saved World" : title)")
        lines.append("par=\(par ?? 10000)")
        lines.append("hint=\(hint)")
        lines.append("")
        lines.append("[playfield]")
        lines.append("size=\(playfield.columns),\(playfield.rows)")
        lines.append("spacing=\(playfield.spacingX),\(playfield.spacingY)")
        lines.append("scale=\(formatJSNumber(playfield.scale))")
        lines.append("")
        lines.append("[background]")
        lines.append("backdrop=\(background?.backdrop ?? "bkg1")")
        lines.append("decals=\(decalsText(background?.decals ?? []))")
        lines.append("bgdecals=\(decalsText(background?.backgroundDecals ?? []))")
        lines.append("")
        lines.append("[partslist]")
        lines.append("types=\(types.joined(separator: ","))")
        lines.append("colors=\(colors.joined(separator: ","))")
        lines.append("parts=\(partLines.joined(separator: ","))")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
#endif
