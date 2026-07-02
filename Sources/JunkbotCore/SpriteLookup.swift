/// Load-time-only resolution of a sprite's atlas name to its generated sprite ID (see
/// `Generated/SpriteTable.swift`) — used by the native path (`LevelEntityBridge.loadLevel`,
/// SDL's texture cache) to resolve level decal/backdrop names. Deliberately a linear scan with
/// raw UTF-8 byte comparison: no String equality/hashing (embedded-WASM-unsafe, though the WASM
/// host resolves names JS-side and never calls this) and never on a per-frame path.
public func spriteIDForName(_ name: String, sheet: SpriteSheet) -> Int32? {
  let target = Array(name.utf8)
  for id in 0..<spriteNameTable.count where spriteSheetTable[id] == sheet.rawValue {
    let candidate = spriteNameTable[id]
    guard candidate.utf8CodeUnitCount == target.count else { continue }
    let matches = candidate.withUTF8Buffer { buffer -> Bool in
      for i in 0..<target.count where buffer[i] != target[i] {
        return false
      }
      return true
    }
    if matches {
      return Int32(id)
    }
  }
  return nil
}

/// Resolves a decal/backdrop name against the standard backgrounds sheet first, then the
/// Undercover-exclusive one — the native-path mirror of JS `drawDecal`'s atlas fallback (JS
/// checks the level's game variant first; the native target plays the standard game, so standard
/// takes priority here).
public func backgroundSpriteIDForName(_ name: String) -> Int32? {
  spriteIDForName(name, sheet: .backgrounds) ?? spriteIDForName(name, sheet: .backgroundsUndercover)
}
