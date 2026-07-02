#if canImport(Foundation)
import Foundation

/// Converts a parsed `Level` (see `LevelParse.swift`) into live `GameEngine` state, so the
/// `Level`/`LevelPart` model — otherwise only used for text I/O — is actually usable to drive the
/// simulation. This is the counterpart to `GameEngine.loadLevel(fromText:)` in `LevelText.swift`,
/// which now just calls `Level(text:)` followed by this method rather than re-parsing text itself.
extension GameEngine {

  /// Resets this engine and loads `level`'s parts as live `entities`, resolving each `LevelPart`
  /// to the appropriate `Entity` via the `make*` factories in `EntityFactory.swift` (brick width
  /// from its type name, facing/on/used from its `PartState`, switch/teleport linkage from its
  /// `relationID`), then sets `levelBounds`/`levelTitle`/`levelHint`/`levelPar` and computes the
  /// initial `winLoseState`. `levelBounds` is left `nil` if `level.playfield.hasExplicitSize` is
  /// `false` — some levels rely on there being no boundary at all.
  public func loadLevel(_ level: Level) {
    resetLevel()

    // The level text format's object relation ID (e.g. "switch1") is an arbitrary string, but
    // Entity.switchID/teleportID are Int32. Map each distinct relation-ID string to a unique
    // per-level integer here (shared between switch/fan/fire/laser and teleport relations, since
    // those are only ever compared within their own kind, never against each other).
    var relationIDsByRawID: [String: Int32] = [:]
    var nextRelationID: Int32 = 1  // start at 1: switchID/teleportID treat 0 as unset elsewhere
    func relationID(_ rawID: String) -> Int32 {
      guard !rawID.isEmpty else { return -1 }
      if let existing = relationIDsByRawID[rawID] { return existing }
      relationIDsByRawID[rawID] = nextRelationID
      nextRelationID += 1
      return nextRelationID - 1
    }

    for part in level.parts {
      let x = Int32((part.gridX - 1) * Double(level.playfield.spacingX))
      let y = Int32((part.gridY - 1) * Double(level.playfield.spacingY))
      let typeName = part.typeName
      let facing: Int32 = part.state == .walkLeft ? -1 : 1
      let facingY: Int32 = part.state == .walkUp ? -1 : (part.state == .walkDown ? 1 : 0)
      let isOn = part.state == .on
      let colorIndex = Int32(part.colorIndex)

      if typeName.hasPrefix("brick_"), let widthInStuds = Int32(typeName.dropFirst("brick_".count)) {
        entities.append(
          makeBrick(
            x: x, y: y, widthInStuds: widthInStuds, colorIndex: colorIndex,
            fixed: part.colorName == "gray"))
      } else if typeName == "minifig" {
        entities.append(makeJunkbot(x: x, y: y - CELL_H * 3, facing: facing))
      } else if typeName == "haz_walker" {
        entities.append(makeGearbot(x: x, y: y - CELL_H, facing: facing))
      } else if typeName == "haz_climber" {
        entities.append(makeClimbbot(x: x, y: y - CELL_H, facing: facing, facingY: facingY))
      } else if typeName == "haz_dumbfloat" {
        entities.append(makeFlybot(x: x, y: y - CELL_H, facing: facing))
      } else if typeName == "haz_float" {
        entities.append(makeEyebot(x: x, y: y - CELL_H, facing: facing, facingY: facingY))
      } else if typeName == "flag" {
        entities.append(makeBin(x: x, y: y - CELL_H * 2, facing: facing))
      } else if typeName == "scaredy" {
        entities.append(makeBin(x: x, y: y - CELL_H * 2, facing: facing, scaredy: true))
      } else if typeName == "haz_slickcrate" {
        entities.append(makeCrate(x: x, y: y - CELL_H))
      } else if typeName == "haz_slickfire" {
        entities.append(makeFire(x: x, y: y, on: isOn, switchID: relationID(part.relationID)))
      } else if typeName == "haz_slickfan" {
        entities.append(makeFan(x: x, y: y, on: isOn, switchID: relationID(part.relationID)))
      } else if typeName == "haz_slicklaser_l" {
        // entity name is confusing in regard to direction, haz_slicklaser_l points right in the game
        entities.append(
          makeLaser(x: x, y: y, facing: 1, on: isOn, switchID: relationID(part.relationID)))
      } else if typeName == "haz_slicklaser_r" {
        // entity name is confusing in regard to direction, haz_slicklaser_r points left in the game
        entities.append(
          makeLaser(x: x, y: y, facing: -1, on: isOn, switchID: relationID(part.relationID)))
      } else if typeName == "haz_slickswitch" {
        entities.append(makeSwitch(x: x, y: y, on: isOn, switchID: relationID(part.relationID)))
      } else if typeName == "haz_slickteleport" {
        entities.append(makeTeleport(x: x, y: y, teleportID: relationID(part.relationID)))
      } else if typeName == "haz_slickjump" {
        entities.append(makeJump(x: x, y: y, fixed: true))
      } else if typeName == "brick_slickjump" {
        entities.append(makeJump(x: x, y: y, fixed: false))
      } else if typeName == "haz_slickshield" {
        entities.append(makeShield(x: x, y: y, used: part.state == .off, fixed: true))
      } else if typeName == "brick_slickshield" {
        entities.append(makeShield(x: x, y: y, used: part.state == .off, fixed: false))
      } else if typeName == "haz_slickpipe" {
        entities.append(makePipe(x: x, y: y))
      } else if typeName == "haz_droplet" {
        entities.append(makeDroplet(x: x, y: y))
      } else {
        fatalError("Unhandled level part type: \(typeName)")
      }
    }

    // Some levels omit `[playfield] size=` entirely and rely on there being no level boundary at
    // all (e.g. placing floor bricks beyond the nominal 35x22 default grid); only set levelBounds
    // when the file actually declared an explicit size.
    if level.playfield.hasExplicitSize {
      levelBounds = LevelBounds(
        x: 0, y: 0, width: Int32(level.playfield.pixelWidth), height: Int32(level.playfield.pixelHeight))
    }
    levelTitle = level.title
    levelHint = level.hint
    levelPar = level.par ?? Int.max
    winLoseState = winOrLose()
  }
}
#endif
