// `Codable` synthesis for `[String: Int]` isn't supported in this project's embedded-Swift/WASM
// build (confirmed: `make all` fails with "type 'SaveData' does not conform to protocol
// 'Encodable'" / "cannot automatically synthesize 'Encodable' because '[String : Int]' does not
// conform to 'Encodable'"). SaveData is SDL3-only anyway - the browser build has its own
// localStorage-based persistence and never touches this type - so it's gated out of the WASM
// build entirely, same as `LevelCatalog.swift`/`LevelParse.swift`.
#if canImport(Foundation)
import Foundation

/// Best-moves-per-level persistence, mirroring the *shape* of `src/game.js`'s relevant
/// `storageKeys` (`score(levelName)`) - storage-mechanism-agnostic: the browser build keys
/// `localStorage` by these values, `JunkbotSDL3` writes this whole struct to a JSON file.
///
/// Deliberately has no locking/"is this level group unlocked" concept - the browser build never
/// implemented level locking either (confirmed: `// @TODO: once there's any locking` in
/// `src/game.js`), so completion is purely informational here, same as there.
public struct SaveData: Codable, Equatable, Sendable {
  /// Best (lowest) move count achieved per level, keyed by level title (matches
  /// `storageKeys.score`'s keying - level titles are unique across a game's level list).
  public var bestMoves: [String: Int]

  public init(bestMoves: [String: Int] = [:]) {
    self.bestMoves = bestMoves
  }

  /// Records a win with `moves` moves, keeping the lower of the existing and new value (matches
  /// `src/game.js`'s `if (!isFinite(formerFewest) || formerFewest >= moves)` gate - ties count as
  /// an improvement, matching "≥" there, not "\>").
  ///
  /// - Returns: `true` if this improved (or set for the first time) the recorded best.
  @discardableResult
  public mutating func recordWin(levelTitle: String, moves: Int) -> Bool {
    if let former = bestMoves[levelTitle], former < moves {
      return false
    }
    bestMoves[levelTitle] = moves
    return true
  }

  public func isCompleted(levelTitle: String) -> Bool {
    bestMoves[levelTitle] != nil
  }

  /// Whether the best recorded run met or beat `par` (matches `completedInMoves <= level.par`).
  public func isGold(levelTitle: String, par: Int?) -> Bool {
    guard let par, let moves = bestMoves[levelTitle] else { return false }
    return moves <= par
  }
}
#endif
