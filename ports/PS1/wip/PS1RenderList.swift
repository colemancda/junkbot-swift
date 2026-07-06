// PS1RenderList.swift — PS1-local replacement for JunkbotCore's
// `RenderCommand`/`RenderFrame`/`RenderList.swift` (see KNOWN_ISSUES.md /
// the plan doc's "Phase 2" section): `RenderFrame.commands` there is a plain
// `Array`, and `RenderList.swift`'s `buildRenderFrame` is a `GameEngine`
// extension -- neither usable without hitting this target's Array bugs or
// requiring a `GameEngine` instance. This ports just the brick/bin/junkbot
// subset of `appendEntityCommand`/`entitySprite`/`junkbotFrame`'s logic
// (verbatim positioning math, simplified to skip states this port's v1 test
// level never reaches: scaredy-bin wobble, Junkbot dying/eating/shield/armor)
// against a `FixedArray`-backed command list instead.

struct PS1RenderCommand {
  var spriteID: Int32
  var x: Int32
  var y: Int32
  var alpha: Int32
}

let maxRenderCommands = 128

func buildRenderCommands(_ state: GameState, into commands: inout FixedArray<128, PS1RenderCommand>) {
  commands.removeAll()
  for e in state.entities {
    let alpha: Int32 = e.grabbed ? 80 : 100

    if e.type == .junkbot {
      let keyframes = e.facing == 1 ? junkbotAnim_walk_r : junkbotAnim_walk_l
      let frame = keyframes[Int(e.animationFrame) % keyframes.count]
      guard frame.spriteID >= 0 else { continue }
      let h = spriteHeightTable[Int(frame.spriteID)]
      commands.append(
        PS1RenderCommand(
          spriteID: frame.spriteID, x: e.x - frame.dx, y: e.y + e.height - 1 - h - frame.dy,
          alpha: alpha))
      continue
    }

    guard let spriteID = ps1SpriteID(for: e) else { continue }
    let h = spriteHeightTable[Int(spriteID)]
    let x: Int32
    let y: Int32
    switch e.type {
    case .brick:
      x = e.x
      y = e.y + e.height - h - 1
    case .bin:
      x = e.x + 4
      y = e.y + e.height - h - 5
    default:
      x = e.x
      y = e.y + e.height - h
    }
    commands.append(PS1RenderCommand(spriteID: spriteID, x: x, y: y, alpha: alpha))
  }
}

/// Ported from `RenderList.swift`'s `entitySprite`, brick/bin cases only
/// (bin's scaredy-wobble branch is skipped -- this port's v1 test level
/// never sets `scaredy`).
private func ps1SpriteID(for e: Entity) -> Int32? {
  switch e.type {
  case .brick:
    let base: Int32
    switch e.colorIndex {
    case 0: base = SpriteID.brickWhiteBase
    case 1: base = SpriteID.brickRedBase
    case 2: base = SpriteID.brickGreenBase
    case 3: base = SpriteID.brickBlueBase
    case 4: base = SpriteID.brickYellowBase
    default: base = SpriteID.brickImmobileBase
    }
    guard e.widthInStuds >= 1 && e.widthInStuds <= 8 else { return nil }
    return base + e.widthInStuds
  case .bin:
    return SpriteID.bin
  default:
    return nil
  }
}
