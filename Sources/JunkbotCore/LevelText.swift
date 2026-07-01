#if canImport(Foundation)
import Foundation

extension GameEngine {

  public func loadLevel(fromText text: String) {
    resetLevel()

    var sections: [String: [(String, String)]] = [:]
    var sectionName = ""
    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
      let trimmed = line.hasSuffix("\r") ? line.dropLast() : line[...]
      if trimmed.range(of: #"^\s*(#.*)?$"#, options: .regularExpression) != nil {
        continue
      }
      if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
        sectionName = String(trimmed.dropFirst().dropLast())
      } else {
        let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        let key = String(parts[0])
        let value = parts.count > 1 ? String(parts[1]) : ""
        sections[sectionName, default: []].append((key, value))
      }
    }

    var title = ""
    var par: Int32 = .max
    if let info = sections["info"] {
      for (key, value) in info {
        if key.caseInsensitiveCompare("title") == .orderedSame {
          title = value
        } else if key.caseInsensitiveCompare("hint") == .orderedSame {
          // hint isn't currently tracked on GameEngine; ignored.
        } else if key.caseInsensitiveCompare("par") == .orderedSame {
          par = Int32(value) ?? .max
        }
      }
    }

    var spacingX: Int32 = 15
    var spacingY: Int32 = 18
    var bounds: LevelBounds? = nil
    if let playfield = sections["playfield"] {
      for (key, value) in playfield where key.caseInsensitiveCompare("spacing") == .orderedSame {
        let parts = value.split(separator: ",").compactMap { Int32($0) }
        if parts.count == 2 {
          spacingX = parts[0]
          spacingY = parts[1]
        }
      }
      for (key, value) in playfield where key.caseInsensitiveCompare("size") == .orderedSame {
        let parts = value.split(separator: ",").compactMap { Int32($0) }
        if parts.count == 2 {
          bounds = LevelBounds(x: 0, y: 0, width: parts[0] * spacingX, height: parts[1] * spacingY)
        }
      }
    }

    guard let partslist = sections["partslist"] else {
      fatalError("No [partslist] section found.")
    }

    var types: [String] = []
    var colors: [String] = []

    // The level text format's object relation ID (field [6], e.g. "switch1") is an arbitrary
    // string, but Entity.switchID/teleportID are Int32. Map each distinct relation-ID string to
    // a unique per-level integer here (shared between switch/fan/fire/laser and teleport
    // relations, since those are only ever compared within their own kind, never against
    // each other).
    var relationIDsByRawID: [String: Int32] = [:]
    var nextRelationID: Int32 = 1  // start at 1: switchID/teleportID treat 0 as unset elsewhere
    func relationID(_ rawID: String) -> Int32 {
      guard !rawID.isEmpty else { return -1 }
      if let existing = relationIDsByRawID[rawID] { return existing }
      relationIDsByRawID[rawID] = nextRelationID
      nextRelationID += 1
      return nextRelationID - 1
    }

    for (key, value) in partslist {
      switch key {
      case "types":
        types.append(contentsOf: value.lowercased().split(separator: ",").map(String.init))
      case "colors":
        colors.append(contentsOf: value.lowercased().split(separator: ",").map(String.init))
      case "parts":
        for entityDef in value.split(separator: ",", omittingEmptySubsequences: false) {
          let e = entityDef.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
          // [0] x, [1] y, [2] type index, [3] color index, [4] starting animation name,
          // [5] starting animation frame, [6] object relation ID (switch/teleport)
          let x = (Int32(e[0])! - 1) * spacingX
          let y = (Int32(e[1])! - 1) * spacingY
          let typeName = types[Int(e[2])! - 1].lowercased()
          let colorName = colors[Int(e[3])! - 1].lowercased()
          let colorIndex = Int32(e[3])! - 1
          let animationName = e[4].lowercased()
          let facing: Int32 = animationName.range(of: "_l", options: .caseInsensitive) != nil ? -1 : 1
          var facingY: Int32 = 0
          if animationName.range(of: "_u", options: .caseInsensitive) != nil {
            facingY = -1
          } else if animationName.range(of: "_d", options: .caseInsensitive) != nil {
            facingY = 1
          }
          let relationRawID = e.count > 6 ? e[6] : ""

          if let brickMatch = typeName.range(of: #"^brick_(\d+)$"#, options: .regularExpression) {
            let widthInStuds = Int32(typeName[brickMatch].split(separator: "_")[1])!
            entities.append(
              makeBrick(
                x: x, y: y, widthInStuds: widthInStuds, colorIndex: colorIndex,
                fixed: colorName == "gray"))
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
            entities.append(
              makeFire(
                x: x, y: y, on: animationName == "on" || animationName == "none",
                switchID: relationID(relationRawID)))
          } else if typeName == "haz_slickfan" {
            entities.append(
              makeFan(
                x: x, y: y, on: animationName == "on" || animationName == "none",
                switchID: relationID(relationRawID)))
          } else if typeName == "haz_slicklaser_l" {
            // entity name is confusing in regard to direction, haz_slicklaser_l points right in the game
            entities.append(
              makeLaser(
                x: x, y: y, facing: 1, on: animationName == "on" || animationName == "none",
                switchID: relationID(relationRawID)))
          } else if typeName == "haz_slicklaser_r" {
            // entity name is confusing in regard to direction, haz_slicklaser_r points left in the game
            entities.append(
              makeLaser(
                x: x, y: y, facing: -1, on: animationName == "on" || animationName == "none",
                switchID: relationID(relationRawID)))
          } else if typeName == "haz_slickswitch" {
            entities.append(
              makeSwitch(
                x: x, y: y, on: animationName == "on" || animationName == "none",
                switchID: relationID(relationRawID)))
          } else if typeName == "haz_slickteleport" {
            entities.append(makeTeleport(x: x, y: y, teleportID: relationID(relationRawID)))
          } else if typeName == "haz_slickjump" {
            entities.append(makeJump(x: x, y: y, fixed: true))
          } else if typeName == "brick_slickjump" {
            entities.append(makeJump(x: x, y: y, fixed: false))
          } else if typeName == "haz_slickshield" {
            entities.append(makeShield(x: x, y: y, used: animationName == "off", fixed: true))
          } else if typeName == "brick_slickshield" {
            entities.append(makeShield(x: x, y: y, used: animationName == "off", fixed: false))
          } else if typeName == "haz_slickpipe" {
            entities.append(makePipe(x: x, y: y))
          } else if typeName == "haz_droplet" {
            entities.append(makeDroplet(x: x, y: y))
          } else {
            fatalError("Unhandled level part type: \(typeName)")
          }
        }
      default:
        break
      }
    }

    levelBounds = bounds
    levelTitle = title
    levelPar = par == .max ? .max : Int(par)
    winLoseState = winOrLose()
  }
}
#endif
