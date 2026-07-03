import Testing

@testable import JunkbotCore

/// Golden tests for the generic renderer (`RenderList.swift` + `Generated/SpriteTable.swift`),
/// pinning emitted sprite IDs, positions, alphas, and ordering against values hand-derived from
/// `src/game.js`'s draw functions and the atlas JSONs — NOT from the Swift implementation.
@Suite("Render list")
struct RenderListTests {

  /// Resolves what an emitted command's sprite ID *should* be by name, via the same table the
  /// backends use — keeps expectations readable while still exercising ID arithmetic.
  private func id(_ name: String, _ sheet: SpriteSheet = .sprites) -> Int32 {
    guard let id = spriteIDForName(name, sheet: sheet) else {
      Issue.record("missing sprite name in generated table: \(name)")
      return -999
    }
    return id
  }

  private func makeEngine() -> GameEngine {
    let engine = GameEngine()
    engine.beginLoadLevel(0, 0, 600, 600)
    engine.addBrick(0, 582, 20, 5, true)  // fixed gray floor at the bottom
    engine.finishLoadLevel()
    return engine
  }

  private func frame(_ engine: GameEngine, editing: Bool = false) -> RenderFrame {
    var frame = RenderFrame()
    engine.buildRenderFrame(into: &frame, editing: editing)
    return frame
  }

  private func spriteCommands(_ frame: RenderFrame) -> [RenderCommand] {
    frame.commands.filter { $0.kind == .sprite }
  }

  @Test("generated table pins: length, spot IDs, sizes, gap slots")
  func generatedTablePins() {
    #expect(spriteNameTable.count == 362)
    #expect(spriteNameTable.count == spriteSheetTable.count)
    #expect(spriteNameTable.count == spriteWidthTable.count)
    #expect(spriteNameTable.count == spriteHeightTable.count)
    // brick families: base + widthInStuds, gaps at widths 5 and 7.
    let green4 = SpriteID.brickGreenBase + 4
    #expect(green4 == id("brick_green_4"))
    #expect(spriteWidthTable[Int(green4)] == 71)
    #expect(spriteHeightTable[Int(green4)] == 32)
    #expect(spriteNameTable[Int(SpriteID.brickGreenBase + 5)].utf8CodeUnitCount == 0)  // gap
    #expect(spriteNameTable[Int(SpriteID.brickGreenBase + 7)].utf8CodeUnitCount == 0)  // gap
    // Undercover sheet membership.
    #expect(spriteSheetTable[Int(id("HAZ_SLICKCRATE", .spritesUndercover))] == 1)
    #expect(spriteWidthTable[Int(id("laserbeam_1_2", .spritesUndercover))] == 15)
    // Background sheets resolvable, with the standard-first fallback.
    #expect(backgroundSpriteIDForName("bkg1") != nil)
    #expect(spriteSheetTable[Int(backgroundSpriteIDForName("bkg1")!)] == 2)
  }

  @Test("brick: color/width ID arithmetic and bottom-aligned position")
  func brickSprite() {
    let engine = makeEngine()
    engine.addBrick(60, 500, 4, 2, false)  // green, 4 studs, at (60, 500), 18 tall
    engine.rebuildAccelerationStructures()
    let commands = spriteCommands(frame(engine))
    // drawBrick: (x, y + height - texH - 1); brick_green_4 is 71x32.
    let expected = RenderCommand.sprite(id("brick_green_4"), x: 60, y: 500 + 18 - 32 - 1)
    #expect(commands.contains { $0.spriteID == expected.spriteID && $0.x == expected.x && $0.y == expected.y && $0.a == 100 })
  }

  @Test("junkbot walk keyframe: sprite + offset table applied")
  func junkbotWalkKeyframe() {
    let engine = makeEngine()
    engine.addJunkbot(120, 510, 1, false)  // facing right, height 72
    engine.rebuildAccelerationStructures()
    let junkbotIndex = engine.entities.firstIndex { $0.type == .junkbot }!
    engine.entities[junkbotIndex].animationFrame = 4  // walk_r[4] = minifig_walk_r_5, offset (8, 0)
    let commands = spriteCommands(frame(engine))
    // drawJunkbot: (x - off.x, y + height - 1 - texH - off.y); minifig_walk_r_5 is 49x79.
    let expected = RenderCommand.sprite(id("minifig_walk_r_5"), x: 120 - 8, y: 510 + 72 - 1 - 79 - 0)
    #expect(commands.contains { $0.spriteID == expected.spriteID && $0.x == expected.x && $0.y == expected.y })
  }

  @Test("junkbot walk keyframe: left walk offset.y")
  func junkbotWalkLeftOffsetY() {
    let engine = makeEngine()
    engine.addJunkbot(120, 510, -1, false)
    engine.rebuildAccelerationStructures()
    let junkbotIndex = engine.entities.firstIndex { $0.type == .junkbot }!
    engine.entities[junkbotIndex].animationFrame = 1  // walk_l[1] = minifig_walk_l_2, offset (0, 4)
    let junkbot = engine.entities[junkbotIndex]
    let frame = engine.junkbotFrame(junkbot)
    #expect(frame.spriteID == id("minifig_walk_l_2"))
    #expect(frame.dx == 0)
    #expect(frame.dy == 4)
  }

  @Test("fire ping-pong: frames 1,2,3,4,5,4,3,2 over an 8-tick period")
  func firePingPong() {
    let engine = makeEngine()
    engine.addFire(60, 564, true, -1)
    engine.rebuildAccelerationStructures()
    let fireIndex = engine.entities.firstIndex { $0.type == .fire }!
    let expectedFrames: [Int32] = [1, 2, 3, 4, 5, 4, 3, 2]
    for tick in 0..<8 {
      engine.entities[fireIndex].animationFrame = Int32(tick)
      let commands = spriteCommands(frame(engine))
      let expectedID = id("haz_slickFire_on_\(expectedFrames[tick])")
      #expect(
        commands.contains { $0.spriteID == expectedID },
        "tick \(tick) should show frame \(expectedFrames[tick])")
    }
  }

  @Test("gearbot: 2-frame facing-aware walk cycle at bottom-1")
  func gearbotSprite() {
    let engine = makeEngine()
    engine.addGearbot(90, 540, -1)
    engine.rebuildAccelerationStructures()
    let gearbotIndex = engine.entities.firstIndex { $0.type == .gearbot }!
    engine.entities[gearbotIndex].animationFrame = 3  // 3 % 2 = 1 -> frame 2
    let g = engine.entities[gearbotIndex]
    let commands = spriteCommands(frame(engine))
    // drawGearbot: (x, y + height - texH - 1); gearbot_walk_l_2 is 35x42.
    let expected = RenderCommand.sprite(id("gearbot_walk_l_2"), x: g.x, y: g.y + g.height - 42 - 1)
    #expect(commands.contains { $0.spriteID == expected.spriteID && $0.x == expected.x && $0.y == expected.y })
  }

  @Test("droplet splash: frame from animationFrame plus drift offset")
  func dropletSplash() {
    let engine = makeEngine()
    var droplet = engine.makeDroplet(x: 150, y: 300)
    droplet.splashing = true
    droplet.animationFrame = 2
    engine.entities.append(droplet)
    engine.rebuildAccelerationStructures()
    let commands = spriteCommands(frame(engine))
    // drawDroplet: (x + 15 + (-3 - af), y - 15) while splashing; frame drip_splashing_3.
    let expected = RenderCommand.sprite(id("drip_splashing_3"), x: 150 + 15 + (-3 - 2), y: 300 - 15)
    #expect(commands.contains { $0.spriteID == expected.spriteID && $0.x == expected.x && $0.y == expected.y })
  }

  @Test("laser beam: per-cell segments, last rightward segment clipped when hitting a non-bin")
  func laserBeamClip() {
    let engine = makeEngine()
    engine.addLaser(0, 546, 1, true, -1)  // facing right ("L" sprite), on
    engine.addCrate(90, 528)  // blocks the beam
    engine.rebuildAccelerationStructures()
    engine.tick()  // populates laserBeams
    #expect(!engine.laserBeams.isEmpty)
    let commands = spriteCommands(frame(engine))
    let beamID0 = SpriteID.laserbeam1Base + 1  // animationFrame dependent; accept any of 3
    let beamCommands = commands.filter { $0.spriteID >= beamID0 && $0.spriteID < beamID0 + 3 }
    #expect(!beamCommands.isEmpty)
    // Exactly one clipped segment (c = 15 - 5 = 10), and it's the furthest-right one.
    let clipped = beamCommands.filter { $0.c != 0 }
    #expect(clipped.count == 1)
    #expect(clipped.first?.c == 10)
    #expect(clipped.first?.x == beamCommands.map(\.x).max())
  }

  @Test("teleport effect: transEfx frame, +5/+2 nudge, bottom anchor, 50% alpha")
  func teleportEffect() {
    let engine = makeEngine()
    engine.teleportEffects.append(TeleportEffect(x: 200, y: 400, frameIndex: 1))
    let commands = spriteCommands(frame(engine))
    // drawTeleportEffect: (x + 5, bottomY - texH + 2), alpha 0.5; transEfx_2 is 28x61.
    let expected = RenderCommand.sprite(id("transEfx_2", .spritesUndercover), x: 205, y: 400 - 61 + 2, alpha: 50)
    #expect(commands.contains { $0.spriteID == expected.spriteID && $0.x == expected.x && $0.y == expected.y && $0.a == 50 })
  }

  @Test("wind: columns between fan edges, extents-limited, frame-offset applied")
  func windColumns() {
    let engine = makeEngine()
    engine.addFan(60, 564, true, -1)
    engine.rebuildAccelerationStructures()
    let fanIndex = engine.entities.firstIndex { $0.type == .fan }!
    engine.entities[fanIndex].animationFrame = 2
    var effect = WindEffect(fanEntityIndex: fanIndex)
    effect.addExtent(2)
    effect.addExtent(1)
    engine.wind.append(effect)
    let fan = engine.entities[fanIndex]
    let commands = spriteCommands(frame(engine))
    let windID = id("fanAir_1_3")  // frame = 1 + (2 % 7)
    let windCommands = commands.filter { $0.spriteID == windID }
    // Fan is 60 wide: columns at x+15 and x+30 -> extents 2 + 1 = 3 command total.
    #expect(windCommands.count == 3)
    // First column, first cell: (x + 15 + 4, (fan.y - 18) - frameIndex*2 + 8).
    let firstX = fan.x + 15 + 4
    let firstY = fan.y - 18 - 2 * 2 + 8
    #expect(windCommands.contains { $0.x == firstX && $0.y == firstY })
  }

  @Test("grabbed drag alpha: 30 when unplaceable, editing forces placeable")
  func grabbedAlpha() {
    let engine = makeEngine()
    // Resting directly on the fixed floor (top edge y=582): downward grab is blocked, so
    // mouseDown starts the upward drag immediately (no pending direction resolution).
    engine.addBrick(60, 564, 2, 1, false)
    engine.finishLoadLevel()
    engine.mouseDown(65, 570)
    #expect(engine.isDragging)
    // Drag to an unplaceable position (mid-air, unattached).
    engine.mouseMove(300, 200)
    var playFrame = RenderFrame()
    engine.buildRenderFrame(into: &playFrame, editing: false)
    #expect(playFrame.placeable == false)
    let grabbedInPlay = playFrame.commands.filter { $0.kind == .sprite && $0.a == 30 }
    #expect(!grabbedInPlay.isEmpty)
    var editFrame = RenderFrame()
    engine.buildRenderFrame(into: &editFrame, editing: true)
    #expect(editFrame.placeable == true)
    let grabbedInEdit = editFrame.commands.filter { $0.kind == .sprite && $0.a == 80 }
    #expect(!grabbedInEdit.isEmpty)
  }

  @Test("bounds mask: four black rects in play mode, none while editing")
  func boundsMask() {
    let engine = makeEngine()
    let playRects = frame(engine).commands.filter { $0.kind == .solidRect }
    #expect(playRects.count == 4)
    #expect(playRects.allSatisfy { $0.c == 0x0000_00FF })
    let editRects = frame(engine, editing: true).commands.filter { $0.kind == .solidRect }
    #expect(editRects.isEmpty)
  }

  @Test("background pass: backdrop and decal offsets, counted for interleaving")
  func backgroundPass() {
    let engine = makeEngine()
    engine.setBackground(
      backdropSpriteID: backgroundSpriteIDForName("bkg1")!,
      backgroundDecals: [DecalInstance(x: 100, y: 50, spriteID: backgroundSpriteIDForName("door")!)],
      decals: [DecalInstance(x: 200, y: 80, spriteID: backgroundSpriteIDForName("window")!)])
    let f = frame(engine)
    #expect(f.backgroundCount == 3)
    // render(): backdrop at (-6,-25), backgroundDecals at (x-3,y-20), decals at (x-30,y-64).
    #expect(f.commands[0].x == -6 && f.commands[0].y == -25)
    #expect(f.commands[1].x == 97 && f.commands[1].y == 30)
    #expect(f.commands[2].x == 170 && f.commands[2].y == 16)
  }

  @Test("painter ordering: lower entity draws before higher stacked entity")
  func paintersOrdering() {
    let engine = makeEngine()
    engine.addBrick(60, 546, 2, 1, false)  // on the floor
    engine.addBrick(60, 528, 2, 2, false)  // stacked directly above
    engine.rebuildAccelerationStructures()
    let commands = spriteCommands(frame(engine))
    let lowerIndex = commands.firstIndex { $0.spriteID == id("brick_red_2") }
    let upperIndex = commands.firstIndex { $0.spriteID == id("brick_green_2") }
    #expect(lowerIndex != nil && upperIndex != nil)
    #expect(lowerIndex! < upperIndex!)
  }

  @Test("building frames never perturbs the simulation RNG stream")
  func simRNGIsolation() {
    let engineA = makeEngine()
    let engineB = makeEngine()
    // engineA renders a scaredy bin (which consumes render RNG for wobble) between ticks.
    engineA.addBin(90, 528, 1, true)
    engineB.addBin(90, 528, 1, true)
    engineA.rebuildAccelerationStructures()
    engineB.rebuildAccelerationStructures()
    for _ in 0..<10 {
      _ = frame(engineA)
      _ = frame(engineA)
      engineA.tick()
      engineB.tick()
    }
    #expect(engineA.rng() == engineB.rng())
  }

  @Test("preview: junkbot walk offset clamped, fan preview wind synthesized")
  func previewCommands() {
    let engine = makeEngine()
    var junkbot = engine.makeJunkbot(x: 0, y: 0, facing: 1)
    junkbot.animationFrame = 4  // walk_r[4] offset.x = 8, clamps to 5 in previews
    let junkbotCommands = engine.buildPreviewCommands(for: junkbot, editing: true)
    let firstX: Int32? = junkbotCommands.first?.x
    #expect(firstX == -5)  // walk_r[4]'s offset.x = 8, clamped to 5 for previews; x = 0 - 5
    var fan = engine.makeFan(x: 0, y: 36, on: true, switchID: -1)
    fan.animationFrame = 0
    let fanCommands = engine.buildPreviewCommands(for: fan, editing: true)
    let windID = id("fanAir_1_1")
    #expect(fanCommands.filter { $0.spriteID == windID }.count == 6)  // 2 columns x extent 3
  }
}
