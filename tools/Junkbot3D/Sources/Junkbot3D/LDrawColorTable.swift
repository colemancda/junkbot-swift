import AppKit
import Foundation

/// Parses `LDConfig.ldr`'s `0 !COLOUR <name> CODE <code> VALUE #RRGGBB EDGE #RRGGBB ...` lines
/// into a code -> RGB lookup, the same table every LDraw-aware tool (LDView, LeoCAD, etc.) ships.
/// We only need the fill color (`VALUE`); edge colors (code 24, "complement") aren't used since
/// the loader's triangle geometry doesn't touch LDraw's own edge-line (type 2/5) records - edges
/// come from `EdgeOutline` instead, matching every other mesh in this tool.
struct LDrawColorTable {
  private var colors: [Int32: NSColor] = [:]

  init(configURL: URL) {
    guard let text = try? String(contentsOf: configURL, encoding: .utf8) else { return }
    for line in text.split(separator: "\n") {
      let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
      guard tokens.count >= 2, tokens[0] == "0", tokens[1] == "!COLOUR" else { continue }
      guard let codeIndex = tokens.firstIndex(of: "CODE"), codeIndex + 1 < tokens.count,
        let code = Int32(tokens[codeIndex + 1]),
        let valueIndex = tokens.firstIndex(of: "VALUE"), valueIndex + 1 < tokens.count
      else { continue }
      guard let color = Self.parseHexColor(String(tokens[valueIndex + 1])) else { continue }
      colors[code] = color
    }
  }

  /// `#RRGGBB` (LDConfig's only VALUE format) to `NSColor`.
  private static func parseHexColor(_ hex: String) -> NSColor? {
    guard hex.hasPrefix("#"), hex.count == 7,
      let rgb = UInt32(hex.dropFirst(), radix: 16)
    else { return nil }
    let r = CGFloat((rgb >> 16) & 0xFF) / 255
    let g = CGFloat((rgb >> 8) & 0xFF) / 255
    let b = CGFloat(rgb & 0xFF) / 255
    return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
  }

  /// Resolves a color code to RGB, including LDraw "direct colours" (`0x2RRGGBB`, encoded as a
  /// large positive number outside the normal palette range) and falling back to a neutral gray
  /// for anything unrecognized (rare - only malformed/unofficial files hit this).
  func color(for code: Int32) -> NSColor {
    if code >= 0x200_0000 {
      let rgb = UInt32(code) & 0xFF_FFFF
      let r = CGFloat((rgb >> 16) & 0xFF) / 255
      let g = CGFloat((rgb >> 8) & 0xFF) / 255
      let b = CGFloat(rgb & 0xFF) / 255
      return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
    }
    return colors[code] ?? NSColor(calibratedWhite: 0.6, alpha: 1)
  }
}
