#if canImport(Foundation)
import Foundation

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
            var backgroundDecals: [LevelDecal] = []
            func parseDecalList(_ value: String) -> [LevelDecal] {
                var result: [LevelDecal] = []
                for entry in value.split(separator: ",") {
                    let f = entry.split(separator: ";").map(String.init)
                    if f.count >= 3, let x = Double(f[0]), let y = Double(f[1]) {
                        result.append(LevelDecal(x: x, y: y, name: f[2]))
                    }
                }
                return result
            }
            for (key, value) in bgEntries {
                switch key.lowercased() {
                case "backdrop":
                    backdrop = value
                case "decals":
                    decals.append(contentsOf: parseDecalList(value))
                case "bgdecals":
                    backgroundDecals.append(contentsOf: parseDecalList(value))
                default: break
                }
            }
            if !backdrop.isEmpty {
                background = LevelBackground(backdrop: backdrop, decals: decals, backgroundDecals: backgroundDecals)
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
#endif
