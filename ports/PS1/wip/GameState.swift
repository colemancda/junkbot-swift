// GameState.swift — PS1-local replacement for JunkbotCore's `GameEngine`
// (see KNOWN_ISSUES.md / the plan doc's "Phase 2" section): a fixed-capacity
// entity store backed by `FixedArray`, plus the `make*` entity-factory
// functions ported from `Sources/JunkbotCore/EntityFactory.swift` (which are
// declared as `GameEngine` extension methods there, so can't be called
// without a `GameEngine` instance -- these are free-standing equivalents
// instead). `Entity`/`EntityType`/`LevelBounds`/`CELL_W`/`CELL_H` are reused
// directly from JunkbotCore's `Types.swift` (plain scalar/tuple structs, no
// `Array`/`Dictionary`, confirmed safe on this target).
//
// v1 scope (see the plan doc): brick/bin/junkbot only.

let maxEntities = 64

final class GameState {
  var entities: FixedArray<64, Entity>
  var levelBounds: LevelBounds?
  var moves: Int32 = 0
  var frameCounter: Int32 = 0
  var winLoseState: Int32 = 0
  var paused = false

  private var idCounter: Int32 = 0

  init() {
    entities = FixedArray<64, Entity>(
      repeating: Entity(id: 0, type: .unknown, x: 0, y: 0, width: 0, height: 0))
  }

  private func getID() -> Int32 {
    idCounter += 1
    return idCounter
  }

  func resetLevel() {
    entities.removeAll()
    idCounter = 0
    frameCounter = 0
    moves = 0
    winLoseState = 0
    levelBounds = nil
    paused = false
  }

  // MARK: - Entity factory (ported from EntityFactory.swift's GameEngine extension)

  func makeBrick(x: Int32, y: Int32, widthInStuds: Int32, colorIndex: Int32, fixed: Bool) -> Entity {
    var e = Entity(id: getID(), type: .brick, x: x, y: y, width: widthInStuds * CELL_W, height: CELL_H)
    e.widthInStuds = widthInStuds
    e.colorIndex = colorIndex
    e.fixed = fixed
    return e
  }

  func makeBin(x: Int32, y: Int32, facing: Int32 = 0, scaredy: Bool = false) -> Entity {
    var e = Entity(id: getID(), type: .bin, x: x, y: y, width: 2 * CELL_W, height: 3 * CELL_H)
    e.facing = facing
    e.scaredy = scaredy
    return e
  }

  func makeJunkbot(x: Int32, y: Int32, facing: Int32, armored: Bool = false) -> Entity {
    var e = Entity(id: getID(), type: .junkbot, x: x, y: y, width: 2 * CELL_W, height: 4 * CELL_H)
    e.facing = facing
    e.armored = armored
    return e
  }
}
