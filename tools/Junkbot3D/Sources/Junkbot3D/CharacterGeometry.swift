import JunkbotCore
import SceneKit

/// Parametric low-poly meshes for entity types with no natural "box + studs" shape. Each is built
/// from primitives sized against the entity's actual game-pixel bounding box, so they line up with
/// collision/placement exactly. Facing (`e.facing`, ±1) rotates the whole node around Y.
enum CharacterGeometry {

  /// Junkbot's real build, part-for-part (per the user's exact spec, not a guess): gray minifig
  /// legs, a 2x2 orange brick (torso), a 2x2 orange slope (roof), and a 2x1 yellow tile (flat
  /// cap) perched on the slope's tall back edge. The brick/slope are sized to the *actual* stud
  /// grid (`e.width`/`Space.depth` are already exactly 2 studs — `makeJunkbot` in
  /// `EntityFactory.swift` sets `width: 2 * CELL_W`), so Junkbot's torso is literally the same
  /// footprint as a 2-stud `BrickGeometry` brick. See `junkbot_character_design` memory for the
  /// design history (this replaced an earlier minifig-body and single-mechanical-leg guess).
  /// Walk-cycle length: matches `junkbotAnim_walk_r`/`_l`'s 10 keyframes (`JunkbotKeyframes.swift`)
  /// so `e.animationFrame % walkCycleLength` lines up with the same cadence the 2D sprite swap
  /// uses, even though the 3D rig is posed procedurally instead of swapping baked art frames.
  static let walkCycleLength: Int32 = 10
  /// Per-leg swing (radians) at the extremes of the stride - a boxy single-material leg reads
  /// fine with a modest swing; anything larger starts clipping into the torso.
  private static let legSwingAmplitude: Double = .pi / 7
  /// Vertical bob (scene units = game pixels, per `Space`'s 1:1 mapping) at mid-stride, roughly
  /// matching the peak `dy` (6px) in the 2D keyframe table's bounce.
  private static let bobAmplitude: CGFloat = 5

  static func junkbot(_ e: Entity) -> SCNNode {
    let root = SCNNode()
    let w = CGFloat(e.width)  // 2 studs
    let h = CGFloat(e.height)  // 4 rows
    let d = Space.depth  // 2 studs

    // Walk-cycle phase: legs swing oppositely (out of phase by pi) around the hip, and the whole
    // figure bobs up on a full-rectified sine (positive twice per cycle, matching a real gait's
    // double bounce - one bounce per footfall) so it lands back at rest height on either leg.
    let phase = 2 * Double.pi * Double(e.animationFrame % walkCycleLength) / Double(walkCycleLength)
    let legSwing = sin(phase) * legSwingAmplitude
    let bob = CGFloat(abs(sin(phase))) * bobAmplitude

    let bodyColor = e.armored ? Palette.enemyBody : Palette.rgb(0xE8, 0x86, 0x18)
    let tileColor = Palette.rgb(0xF4, 0xD8, 0x20)
    let legColor = Palette.rgb(0x9A, 0x9A, 0x9E)

    let torsoH = Space.rowH  // 2x2 brick: one row tall
    let slopeH = Space.rowH  // 2x2 slope: one row tall (at its tall/back edge)
    let tileH = Space.rowH * 0.33  // a tile is much thinner than a brick
    let legH = h - torsoH - slopeH - tileH  // fill the rest of the entity's 4-row box

    // Gray minifig legs: a hip block over two separate leg blocks with a thin center gap.
    let legNode = SCNNode()
    let hipH = legH * 0.28
    let hip = SCNBox(width: w * 0.95, height: hipH, length: d * 0.85, chamferRadius: 1)
    hip.firstMaterial = Palette.material(legColor)
    let hipNode = SCNNode(geometry: hip)
    hipNode.position = SCNVector3(0, legH - hipH / 2, 0)
    legNode.addChildNode(hipNode)

    // Each leg must be offset along local *z*, not local x: the whole figure gets rotated 90°
    // around Y below to face down the level's travel axis, which maps local z to world x and
    // local x to world z. The framing camera looks in almost the same direction as world z (see
    // `SceneBuilder.framingCameraNode`'s `distance*0.75` z-heavy position), so a world-z offset
    // between the two legs is nearly invisible (foreshortened away) - offsetting along local x
    // instead (the bug this replaces) made both legs land on top of each other on screen. A
    // local-z offset maps to world x, which the camera views nearly broadside, so the two legs
    // actually read as separate.
    let legPieceH = legH - hipH
    let legPieceVisibleWidth = w * 0.24  // local z -> world x: the screen-visible leg width
    let legPieceBulk = d * 0.7  // local x -> world z: mostly foreshortened, can stay generous
    for side: CGFloat in [-1, 1] {
      let legPiece = SCNBox(
        width: legPieceBulk, height: legPieceH, length: legPieceVisibleWidth, chamferRadius: 1)
      legPiece.firstMaterial = Palette.material(legColor)
      let legPieceNode = SCNNode(geometry: legPiece)
      // Offset *below* the pivot (not centered on it) so rotating the pivot swings the leg like a
      // hinge at the hip instead of spinning it in place around its own center.
      legPieceNode.position = SCNVector3(0, -legPieceH / 2, 0)
      legPieceNode.addChildNode(
        EdgeOutline.box(width: legPieceBulk, height: legPieceH, length: legPieceVisibleWidth))

      // A pivot node at hip height carries the swing rotation; the two legs swing oppositely
      // (`side` flips the sign) and the local-z offset (screen-visible spread between the legs)
      // moves with the swing instead of staying fixed, matching how a real hinge would translate
      // the whole leg forward/back as it swings around local X.
      let pivotNode = SCNNode()
      pivotNode.position = SCNVector3(0, legPieceH, side * legPieceVisibleWidth * 0.65)
      pivotNode.eulerAngles.x = CGFloat(side * legSwing)
      pivotNode.addChildNode(legPieceNode)
      legNode.addChildNode(pivotNode)
    }
    hipNode.addChildNode(EdgeOutline.box(width: w * 0.95, height: hipH, length: d * 0.85))
    legNode.position = SCNVector3(0, -h / 2, 0)
    root.addChildNode(legNode)

    // Torso: a real 2x2 brick (full stud-grid footprint), with decal-textured front/side
    // materials (SCNBox materials order is front, right, back, left, top, bottom).
    let torso = SCNBox(width: w, height: torsoH, length: d, chamferRadius: 1)
    let plainMat = Palette.material(bodyColor)
    let frontMat = SCNMaterial()
    frontMat.diffuse.contents = DecalTextures.front(bodyColor: bodyColor)
    frontMat.lightingModel = .lambert
    let sideMat = SCNMaterial()
    sideMat.diffuse.contents = DecalTextures.side(bodyColor: bodyColor)
    sideMat.lightingModel = .lambert
    torso.materials = [frontMat, sideMat, plainMat, plainMat, plainMat, plainMat]
    let torsoNode = SCNNode(geometry: torso)
    // Bob only the upper body (torso/roof/tile) so the legs stay planted and swing at the hip -
    // matches a real gait's silhouette (rising over the stance leg) better than bobbing the whole
    // figure, which would visibly lift the feet off the ground at the bounce's peak.
    torsoNode.position = SCNVector3(0, -h / 2 + legH + torsoH / 2 + bob, 0)
    torsoNode.addChildNode(EdgeOutline.box(width: w, height: torsoH, length: d))
    root.addChildNode(torsoNode)

    // Roof: a 2x2 slope, same footprint as the torso brick, sloping down from a full-row back
    // edge to zero height at the front.
    let roof = Wedge.geometry(width: w, depth: d, height: slopeH)
    roof.firstMaterial = Palette.material(bodyColor)
    let roofNode = SCNNode(geometry: roof)
    roofNode.position = SCNVector3(0, torsoNode.position.y + torsoH / 2, 0)
    root.addChildNode(roofNode)

    // Cap: a 2x1 flat tile (studless, thin) resting on the slope's tall back edge.
    let tile = SCNBox(width: w, height: tileH, length: Space.studW, chamferRadius: 0.5)
    tile.firstMaterial = Palette.material(tileColor)
    let tileNode = SCNNode(geometry: tile)
    tileNode.position = SCNVector3(
      0, roofNode.position.y + slopeH + tileH / 2, -d / 2 + Space.studW / 2)
    tileNode.addChildNode(EdgeOutline.box(width: w, height: tileH, length: Space.studW))
    root.addChildNode(tileNode)

    // Characters walk along the level's horizontal (world x) axis, not toward the camera:
    // rotate so the mesh's decal-marked front (local +z) points down that axis instead of at
    // the viewer — +x (facing 1) or -x (facing -1).
    root.eulerAngles.y = e.facing == 1 ? .pi / 2 : -.pi / 2
    return root
  }

  /// Boxy enemy robots (gearbot/climbbot/flybot/eyebot) share one blocky chassis with an accent
  /// "eye" stripe; visually distinct enough per-type isn't critical for the Phase 1 look-and-feel
  /// pass, so all four reuse this until dedicated meshes are worth the effort.
  static func robot(_ e: Entity) -> SCNNode {
    let root = SCNNode()
    let w = CGFloat(e.width)
    let h = CGFloat(e.height)
    let d = Space.depth

    let chassis = SCNBox(width: w * 0.8, height: h * 0.8, length: d, chamferRadius: 1)
    chassis.firstMaterial = Palette.material(Palette.enemyBody)
    let chassisNode = SCNNode(geometry: chassis)
    chassisNode.addChildNode(EdgeOutline.box(width: w * 0.8, height: h * 0.8, length: d))
    root.addChildNode(chassisNode)

    let eye = SCNBox(width: w * 0.3, height: h * 0.15, length: d * 0.55, chamferRadius: 0.5)
    eye.firstMaterial = Palette.material(Palette.enemyAccent)
    let eyeNode = SCNNode(geometry: eye)
    eyeNode.position = SCNVector3(w * 0.15, h * 0.15, 0)
    eyeNode.addChildNode(EdgeOutline.box(width: w * 0.3, height: h * 0.15, length: d * 0.55))
    root.addChildNode(eyeNode)

    // Characters walk along the level's horizontal (world x) axis, not toward the camera:
    // rotate so the mesh's decal-marked front (local +z) points down that axis instead of at
    // the viewer — +x (facing 1) or -x (facing -1).
    root.eulerAngles.y = e.facing == 1 ? .pi / 2 : -.pi / 2
    return root
  }

  /// The trash bin: a round drum (per reference art, not a box) — a cylindrical body, a slightly
  /// wider collar ring at the seam, and a low domed lid — with a recycle-glyph sticker on the
  /// front applied via a flat plane (a texture on the curved body would wrap/stretch around the
  /// whole circumference instead of reading as one decal).
  static func bin(_ e: Entity) -> SCNNode {
    let root = SCNNode()
    let w = CGFloat(e.width)
    let h = CGFloat(e.height)
    let radius = w * 0.42

    let bodyH = h * 0.72
    let body = SCNCylinder(radius: radius, height: bodyH)
    body.radialSegmentCount = 12
    body.firstMaterial = Palette.material(Palette.binColor)
    let bodyNode = SCNNode(geometry: body)
    bodyNode.position = SCNVector3(0, -h / 2 + bodyH / 2, 0)
    root.addChildNode(bodyNode)

    let collarColor = Palette.binColor.blended(withFraction: 0.2, of: .white) ?? Palette.binColor
    let collar = SCNCylinder(radius: radius * 1.06, height: h * 0.06)
    collar.radialSegmentCount = 12
    collar.firstMaterial = Palette.material(collarColor)
    let collarNode = SCNNode(geometry: collar)
    collarNode.position = SCNVector3(0, -h / 2 + bodyH - h * 0.03, 0)
    root.addChildNode(collarNode)

    let lid = SCNCylinder(radius: radius * 0.94, height: h * 0.16)
    lid.radialSegmentCount = 12
    lid.firstMaterial = Palette.material(collarColor)
    let lidNode = SCNNode(geometry: lid)
    lidNode.position = SCNVector3(0, -h / 2 + bodyH + h * 0.08, 0)
    root.addChildNode(lidNode)

    let stickerMat = SCNMaterial()
    stickerMat.diffuse.contents = DecalTextures.recycleSticker(color: .white)
    stickerMat.lightingModel = .lambert
    stickerMat.isDoubleSided = true
    stickerMat.blendMode = .alpha
    stickerMat.writesToDepthBuffer = false
    let sticker = SCNPlane(width: w * 0.5, height: w * 0.5)
    sticker.firstMaterial = stickerMat
    let stickerNode = SCNNode(geometry: sticker)
    stickerNode.position = SCNVector3(0, -h / 2 + bodyH / 2, radius + 0.5)
    root.addChildNode(stickerNode)

    return root
  }

  /// Fallback for every hazard/decoration type without a dedicated mesh yet (fire, fan, switch,
  /// pipe, shield, teleport, laser, jump, droplet, crate): a flat-colored box sized to the
  /// entity's bounds, tinted by type so different hazards are still visually distinguishable.
  static func genericBox(_ e: Entity) -> SCNNode {
    let w = CGFloat(e.width)
    let h = CGFloat(e.height)
    let d = Space.depth * 0.6
    let box = SCNBox(width: w, height: h, length: d, chamferRadius: 0.5)
    box.firstMaterial = Palette.material(hazardColor(e.type))
    let node = SCNNode(geometry: box)
    node.addChildNode(EdgeOutline.box(width: w, height: h, length: d))
    return node
  }

  private static func hazardColor(_ type: EntityType) -> NSColor {
    switch type {
    case .fire: return Palette.rgb(0xE0, 0x50, 0x10)
    case .fan: return Palette.rgb(0xB0, 0xC8, 0xD8)
    case .switch: return Palette.rgb(0xE0, 0xC0, 0x30)
    case .pipe: return Palette.rgb(0x60, 0x70, 0x80)
    case .shield: return Palette.rgb(0x40, 0xB0, 0xE0)
    case .teleport: return Palette.rgb(0x90, 0x40, 0xC0)
    case .laser: return Palette.rgb(0xD0, 0x20, 0x20)
    case .jump: return Palette.rgb(0xE0, 0x90, 0x20)
    case .droplet: return Palette.rgb(0x40, 0x90, 0xE0)
    case .crate: return Palette.rgb(0x9A, 0x7A, 0x4A)
    default: return Palette.rgb(0x80, 0x80, 0x80)
    }
  }
}
