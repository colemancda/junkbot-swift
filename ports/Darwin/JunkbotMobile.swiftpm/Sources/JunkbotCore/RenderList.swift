/// The generic world renderer: turns `GameEngine` state into an ordered `RenderFrame` of
/// platform-independent `RenderCommand`s, porting the *decision* half of `src/game.js`'s world
/// drawing (`drawBrick`...`drawJunkbot`, `drawWind`/`drawLaserBeam`/`drawTeleportEffect`,
/// `drawDecal` calls, the play-mode bounds mask, grabbed-drag alpha, and painter's-algorithm
/// ordering). Backends (JS canvas via the JunkbotWASM bridge, native SDL3) only execute commands.
///
/// Everything here is embedded-WASM-safe: sprite identity is pure Int32 arithmetic over the
/// generated tables (`Generated/SpriteTable.swift`), no String operations, no Dictionary.

/// One placed background decal, with its name already resolved to a sprite ID at level-load time
/// (by the JS host via `engineSetBackground`, or natively via `spriteIDForName`).
public struct DecalInstance {
  public var x: Int32
  public var y: Int32
  public var spriteID: Int32

  public init(x: Int32, y: Int32, spriteID: Int32) {
    self.x = x
    self.y = y
    self.spriteID = spriteID
  }
}

extension GameEngine {

  /// Replaces the level's background layers (called once per level load).
  public func setBackground(
    backdropSpriteID: Int32, backgroundDecals: [DecalInstance], decals: [DecalInstance]
  ) {
    self.backdropSpriteID = backdropSpriteID
    self.backgroundDecals = backgroundDecals
    self.decals = decals
  }

  /// Builds the complete world frame. `entitiesOverride` (the JS editor path, whose mirror is
  /// authoritative for editor-only mutations) replaces `self.entities` as the sprite source;
  /// effects/decals/mask still come from engine state.
  public func buildRenderFrame(
    into frame: inout RenderFrame, editing: Bool, entitiesOverride: [Entity]? = nil
  ) {
    frame.commands.removeAll(keepingCapacity: true)

    // 1. Background pass: backdrop at (-6,-25), far decals at (x-3,y-20), near decals at
    //    (x-30,y-64) - offsets from render() in src/game.js.
    if backdropSpriteID >= 0 {
      frame.commands.append(.sprite(backdropSpriteID, x: -6, y: -25))
    }
    for d in backgroundDecals {
      frame.commands.append(.sprite(d.spriteID, x: d.x - 3, y: d.y - 20))
    }
    for d in decals {
      frame.commands.append(.sprite(d.spriteID, x: d.x - 30, y: d.y - 64))
    }
    frame.backgroundCount = frame.commands.count

    // 2. Matches JS canRelease()'s editing short-circuit (always releasable while editing).
    frame.placeable = editing || canRelease()

    // 3. Entities, painter-sorted.
    let renderEntities = entitiesOverride ?? entities
    var boxes: [RenderBox] = []
    boxes.reserveCapacity(renderEntities.count)
    for e in renderEntities {
      boxes.append(
        RenderBox(
          x: Double(e.x), y: Double(e.y), width: Double(e.width), height: Double(e.height)))
    }
    for index in sortOrderForRendering(boxes) {
      appendEntityCommand(
        renderEntities[index], placeable: frame.placeable, editing: editing,
        into: &frame.commands)
    }

    // 4. Effect overlays (engine-owned per-tick state).
    appendWindCommands(into: &frame.commands)
    appendLaserBeamCommands(into: &frame.commands)
    appendTeleportEffectCommands(into: &frame.commands)

    // 5. Play-mode bounds mask: JS drew a lineWidth-10000 black strokeRect around the bounds;
    //    equivalent coverage as four filled rects 5000px deep on each side.
    if !editing, let bounds = levelBounds {
      let d: Int32 = 5000
      let black: Int32 = 0x0000_00FF
      frame.commands.append(
        .solidRect(x: bounds.x - d, y: bounds.y - d, width: d, height: bounds.height + 2 * d, rgba: black))
      frame.commands.append(
        .solidRect(x: bounds.x + bounds.width, y: bounds.y - d, width: d, height: bounds.height + 2 * d, rgba: black))
      frame.commands.append(
        .solidRect(x: bounds.x, y: bounds.y - d, width: bounds.width, height: d, rgba: black))
      frame.commands.append(
        .solidRect(x: bounds.x, y: bounds.y + bounds.height, width: bounds.width, height: d, rgba: black))
    }
  }

  /// Entity sprites only, painter-sorted - the JS playback-ghost overlay.
  public func buildEntityListCommands(_ ghostEntities: [Entity]) -> [RenderCommand] {
    var commands: [RenderCommand] = []
    var boxes: [RenderBox] = []
    boxes.reserveCapacity(ghostEntities.count)
    for e in ghostEntities {
      boxes.append(
        RenderBox(
          x: Double(e.x), y: Double(e.y), width: Double(e.width), height: Double(e.height)))
    }
    for index in sortOrderForRendering(boxes) {
      appendEntityCommand(ghostEntities[index], placeable: true, editing: false, into: &commands)
    }
    return commands
  }

  /// One entity plus synthesized preview effects - the editor's palette buttons. Mirrors the
  /// palette-preview code in src/game.js (fan wind with extents [3,3]; teleport effect while the
  /// entity's post-cooldown timer window is active; Junkbot's walk offset clamped so the preview
  /// doesn't wander, matching JS's `isPreviewEntity` clamp of offset.x to 5).
  public func buildPreviewCommands(for entity: Entity, editing: Bool) -> [RenderCommand] {
    var commands: [RenderCommand] = []
    appendEntityCommand(
      entity, placeable: true, editing: editing, into: &commands, isPreview: true)
    if entity.type == .fan, entity.on {
      var previewWind = WindEffect(fanEntityIndex: -1)
      previewWind.addExtent(3)
      previewWind.addExtent(3)
      appendWindCommands(for: previewWind, fan: entity, into: &commands)
    }
    if entity.type == .teleport, entity.timer > TELEPORT_COOLDOWN - TELEPORT_EFFECT_PERIOD {
      appendTeleportEffectCommand(
        TeleportEffect(x: entity.x + CELL_W, y: entity.y, frameIndex: entity.timer % 3),
        into: &commands)
    }
    return commands
  }

  // MARK: - Entities

  func appendEntityCommand(
    _ e: Entity, placeable: Bool, editing: Bool, into commands: inout [RenderCommand],
    isPreview: Bool = false
  ) {
    let alpha: Int32 = e.grabbed ? (placeable ? 80 : 30) : 100

    if e.type == .junkbot {
      let frame = junkbotFrame(e, isPreview: isPreview)
      guard frame.spriteID >= 0 else { return }
      let h = spriteHeightTable[Int(frame.spriteID)]
      commands.append(
        .sprite(
          frame.spriteID, x: e.x - frame.dx, y: e.y + e.height - 1 - h - frame.dy, alpha: alpha))
      return
    }

    guard let sprite = entitySprite(e, editing: editing) else { return }
    let w = spriteWidthTable[Int(sprite.id)]
    let h = spriteHeightTable[Int(sprite.id)]
    let x: Int32
    let y: Int32
    switch e.type {
    case .brick:
      x = e.x
      y = e.y + e.height - h - 1
    case .bin:
      x = e.x + 4
      y = e.y + e.height - h - 5
    case .crate, .switch, .shield, .teleport, .jump, .gearbot, .flybot, .eyebot:
      x = e.x
      y = e.y + e.height - h - 1
    case .fire, .fan:
      x = e.x + 1
      y = e.y + e.height - h - 4
    case .pipe:
      x = e.x + 11
      y = e.y - 12
    case .droplet:
      // JS drawDroplet's splash offset approximation: drifts left/up while splashing.
      let splash: Int32 = e.splashing ? 1 : 0
      x = e.x + 15 + (-3 - e.animationFrame) * splash
      y = e.y + (-15) * splash
    case .climbbot:
      x = e.x
      y = e.y - 6
    case .laser:
      // Sprite/entity naming is inverted vs. direction; facing == -1 is drawn right-aligned.
      if e.facing == -1 {
        x = e.x + e.width - w + 11
      } else {
        x = e.x
      }
      y = e.y + e.height - 1 - h
    default:
      x = e.x
      y = e.y + e.height - h
    }
    commands.append(
      .sprite(sprite.id, x: x, y: y, alpha: alpha, rotationMrad: sprite.rotationMrad))
  }

  /// Sprite ID (plus wobble rotation for scaredy bins) for every entity type except Junkbot,
  /// mirroring src/game.js's per-type draw functions. Returns nil for types with nothing to draw.
  private func entitySprite(_ e: Entity, editing: Bool) -> (id: Int32, rotationMrad: Int32)? {
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
      return (base + e.widthInStuds, 0)

    case .bin:
      if e.scaredy && (e.facing != 0 || editing) {
        // JS: frameIndex = animationFrame % 2, forced to 1 while editing (no wobble either).
        let frameIndex = editing ? 1 : e.animationFrame % 2
        let id: Int32
        if e.facing == 1 {
          id = frameIndex == 0 ? SpriteID.scaredyWalkR1S3 : SpriteID.scaredyWalkR2S3
        } else {
          id = frameIndex == 0 ? SpriteID.scaredyWalkL1S3 : SpriteID.scaredyWalkL2S3
        }
        // JS wobbles with (Math.random() - 0.5) / 4 radians per drawn frame; use the dedicated
        // render RNG (never the simulation RNG - replays/determinism must be unaffected).
        let rotation = editing ? 0 : renderRandomMilliradians(range: 125)
        return (id, rotation)
      }
      return (SpriteID.bin, 0)

    case .crate:
      return (SpriteID.hazSlickcrate, 0)

    case .fire:
      guard e.on else { return (SpriteID.hazSlickFireOffBase + 1, 0) }
      // Ping-pong 1,2,3,4,5,4,3,2 over an 8-tick period.
      let m4 = e.animationFrame % 4
      let frameIndex = e.animationFrame % 8 < 4 ? m4 : 4 - m4
      return (SpriteID.hazSlickFireOnBase + 1 + frameIndex, 0)

    case .fan:
      guard e.on else { return (SpriteID.hazSlickFanOffBase + 1, 0) }
      return (SpriteID.hazSlickFanOnBase + 1 + e.animationFrame % 4, 0)

    case .switch:
      return (e.on ? SpriteID.hazSlickSwitchOnBase + 1 : SpriteID.hazSlickSwitchOffBase + 1, 0)

    case .pipe:
      let wet = e.timer <= 6 && e.timer > -1
      guard wet else { return (SpriteID.hazSlickPipeDryBase + 1, 0) }
      return (SpriteID.hazSlickPipeWetBase + 1 + (6 - e.timer), 0)

    case .shield:
      if e.fixed {
        return (e.used ? SpriteID.hazSlickshieldOff : SpriteID.hazSlickshieldOn, 0)
      }
      return (e.used ? SpriteID.brickSlickshieldOff : SpriteID.brickSlickshieldOn, 0)

    case .teleport:
      if e.timer > 30 {
        return (SpriteID.hazSlickTeleportActiveBase + 1 + e.timer % 2, 0)
      }
      let on = e.timer == 0 && !e.blocked
      return (on ? SpriteID.hazSlickTeleportOnBase + 1 : SpriteID.hazSlickTeleportOffBase + 1, 0)

    case .laser:
      // Sprite letter is inverted relative to facing (see drawLaser in src/game.js).
      return (
        e.facing == 1 ? SpriteID.hazSlickLaserLOnBase + 1 : SpriteID.hazSlickLaserROnBase + 1, 0
      )

    case .jump:
      if e.active {
        let base = e.fixed ? SpriteID.hazSlickJumpActiveBase : SpriteID.brickSlickJumpActiveBase
        return (base + 1 + e.animationFrame % 5, 0)
      }
      let base = e.fixed ? SpriteID.hazSlickJumpDormantBase : SpriteID.brickSlickJumpDormantBase
      return (base + 1, 0)

    case .droplet:
      guard e.splashing else { return (SpriteID.dripFallingBase + 1, 0) }
      let frame = min(e.animationFrame, SpriteID.dripSplashingCount - 1)
      return (SpriteID.dripSplashingBase + 1 + frame, 0)

    case .gearbot:
      let base = e.facing == 1 ? SpriteID.gearbotWalkRBase : SpriteID.gearbotWalkLBase
      return (base + 1 + e.animationFrame % 2, 0)

    case .climbbot:
      let base: Int32
      if e.facingY == -1 {
        base = SpriteID.climbbotWalkUBase
      } else if e.facingY == 1 {
        base = SpriteID.climbbotWalkDBase
      } else {
        base = e.facing == 1 ? SpriteID.climbbotWalkRBase : SpriteID.climbbotWalkLBase
      }
      return (base + 1 + e.animationFrame % 6, 0)

    case .flybot:
      return (SpriteID.flybotBase + 1 + e.animationFrame % 2, 0)

    case .eyebot:
      let base = e.activeTimer > 0 ? SpriteID.eyebotActiveBase : SpriteID.eyebotBase
      return (base + 1 + e.animationFrame % 2, 0)

    case .junkbot, .levelBounds, .unknown:
      return nil
    }
  }

  /// Junkbot's current sprite + pixel offset, mirroring drawJunkbot in src/game.js: the walk
  /// cycles use the generated keyframe/offset tables (`Generated/JunkbotKeyframes.swift`); every
  /// other state uses the `minifig_<anim>_<frame>` family naming with no offset. Returns
  /// spriteID -1 for state combinations with no sprite (e.g. armored death - unreachable in
  /// practice; JS would throw on the missing atlas entry, we skip drawing instead).
  func junkbotFrame(_ e: Entity, isPreview: Bool = false) -> (spriteID: Int32, dx: Int32, dy: Int32)
  {
    if e.dead {
      return (SpriteID.minifigDead, 0, 0)
    }
    // JS's armored-overlay renaming only applies to states with shield_ variants in the atlas;
    // armored death states don't exist (and can't occur - armor absorbs the hit).
    let armoredVisible = e.armored && (!e.losingShield || e.animationFrame % 4 < 2)

    if e.dyingFromWater {
      return (SpriteID.minifigWaterDieBase + 1 + e.animationFrame % 10, 0, 0)
    }
    if e.dying {
      return (SpriteID.minifigDieBase + 1 + e.animationFrame % 10, 0, 0)
    }
    if e.collectingBin {
      let base = armoredVisible ? SpriteID.minifigShieldEatBase : SpriteID.minifigEatStartBase
      return (base + 1 + e.animationFrame % 17, 0, 0)
    }
    if e.gettingShield {
      let base = e.facing == 1 ? SpriteID.minifigShieldOnRBase : SpriteID.minifigShieldOnLBase
      return (base + 1 + e.animationFrame % 11, 0, 0)
    }

    let keyframes: [JunkbotKeyframe]
    if armoredVisible {
      keyframes = e.facing == 1 ? junkbotAnim_shield_walk_r : junkbotAnim_shield_walk_l
    } else {
      keyframes = e.facing == 1 ? junkbotAnim_walk_r : junkbotAnim_walk_l
    }
    let frame = keyframes[Int(e.animationFrame) % keyframes.count]
    // The editor palette clamps the walk cycle's horizontal offset so the preview doesn't
    // wander off its button (JS: `if (junkbot.isPreviewEntity && offset.x >= 5) offset.x = 5`).
    let dx = isPreview && frame.dx >= 5 ? 5 : frame.dx
    return (frame.spriteID, dx, frame.dy)
  }

  // MARK: - Effects

  private func appendWindCommands(into commands: inout [RenderCommand]) {
    for effect in wind {
      guard effect.fanEntityIndex >= 0 && effect.fanEntityIndex < entities.count else { continue }
      appendWindCommands(for: effect, fan: entities[effect.fanEntityIndex], into: &commands)
    }
  }

  /// Port of drawWind (src/game.js): one column per stud between the fan's edges, each drawn
  /// upward `extents[i]` cells, using the 7-frame fanAir cycle with a rising per-frame offset.
  private func appendWindCommands(
    for effect: WindEffect, fan: Entity, into commands: inout [RenderCommand]
  ) {
    let frameIndex = fan.animationFrame % 7
    let spriteID = SpriteID.fanAir1Base + 1 + frameIndex
    var columnIndex = 0
    var x = fan.x + 15
    while x < fan.x + fan.width - 15 {
      var extent: Int32 = 0
      var y = fan.y - 18
      while y > -200 {
        if extent >= effect.extent(at: columnIndex) { break }
        extent += 1
        commands.append(.sprite(spriteID, x: x + 4, y: y - frameIndex * 2 + 8))
        y -= 18
      }
      columnIndex += 1
      x += 15
    }
  }

  /// Port of drawLaserBeam: one segment per grid cell of the beam's extent, with the final
  /// segment's width trimmed by 5px when a rightward beam hits something other than a bin
  /// (JS's "depth illusion").
  private func appendLaserBeamCommands(into commands: inout [RenderCommand]) {
    for beam in laserBeams {
      guard beam.laserEntityIndex >= 0 && beam.laserEntityIndex < entities.count else { continue }
      let brick = entities[beam.laserEntityIndex]
      guard brick.on else { continue }
      let frameIndex = brick.animationFrame % 3
      let spriteID = SpriteID.laserbeam1Base + 1 + frameIndex
      var extent: Int32 = 0
      while extent < beam.extent {
        let x = brick.x + (brick.facing == 1 ? brick.width : -15) + 15 * extent * brick.facing
        var clipWidth: Int32 = 0
        if extent == beam.extent - 1, brick.facing == 1, beam.hitEntityIndex >= 0,
          beam.hitEntityIndex < entities.count, entities[beam.hitEntityIndex].type != .bin
        {
          clipWidth = spriteWidthTable[Int(spriteID)] - 5
        }
        commands.append(.sprite(spriteID, x: x + 4, y: brick.y, clipWidth: clipWidth))
        extent += 1
      }
    }
  }

  private func appendTeleportEffectCommands(into commands: inout [RenderCommand]) {
    for effect in teleportEffects {
      appendTeleportEffectCommand(effect, into: &commands)
    }
  }

  /// Port of drawTeleportEffect: transEfx frame at half opacity, bottom-anchored with a (+5,+2)
  /// nudge (`effect.y` is the bottom edge).
  private func appendTeleportEffectCommand(
    _ effect: TeleportEffect, into commands: inout [RenderCommand]
  ) {
    let spriteID = SpriteID.transEfxBase + 1 + effect.frameIndex % 3
    let h = spriteHeightTable[Int(spriteID)]
    commands.append(.sprite(spriteID, x: effect.x + 5, y: effect.y - h + 2, alpha: 50))
  }

  // MARK: - Render RNG

  /// A uniformly-distributed value in `-range...range`, from the render-only xorshift stream
  /// (`renderRNGState`) so cosmetic randomness (scaredy-bin wobble) never perturbs the
  /// simulation RNG sequence that replays/rewind determinism depend on.
  private func renderRandomMilliradians(range: Int32) -> Int32 {
    renderRNGState ^= renderRNGState << 13
    renderRNGState ^= renderRNGState >> 17
    renderRNGState ^= renderRNGState << 5
    let unit = Float(renderRNGState & 0x7FFF_FFFF) / Float(0x7FFF_FFFF)
    return Int32((unit - 0.5) * 2 * Float(range))
  }
}
