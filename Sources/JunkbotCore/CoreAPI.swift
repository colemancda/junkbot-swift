import JunkbotCoreBridge

nonisolated(unsafe) var renderCallbacks: JunkbotRenderCallbacks? = nil

@c public func core_init() {
    rngState = 42
    resetLevel()
}

@c public func core_set_render_callbacks(_ callbacks: JunkbotRenderCallbacks) {
    renderCallbacks = callbacks
}

@c public func core_tick() {
    guard !paused else { return }
    simulate()
    renderFrame()
}

@c public func core_finish_load_level() {
    rebuildAccelerationStructures()
    winLoseState = winOrLose()
    renderFrame()
}

func packEntityState(_ e: Entity) -> JunkbotEntityState {
    var s = JunkbotEntityState()
    s.id = e.id
    s.type = Int32(e.type.rawValue)
    s.x = e.x
    s.y = e.y
    s.width = e.width
    s.height = e.height
    s.facing = e.facing
    s.facingY = e.facingY
    s.animationFrame = e.animationFrame
    s.widthInStuds = e.widthInStuds
    s.colorIndex = e.colorIndex
    s.grabbed = e.grabbed
    s.fixed = e.fixed
    s.removeBeforeRender = e.removeBeforeRender
    s.armored = e.armored
    s.losingShield = e.losingShield
    s.gettingShield = e.gettingShield
    s.dead = e.dead
    s.collectingBin = e.collectingBin
    s.headLoaded = e.headLoaded
    s.scaredy = e.scaredy
    s.on = e.on
    s.used = e.used
    s.blocked = e.blocked
    s.active = e.active
    s.splashing = e.splashing
    s.switchID = e.switchID
    s.teleportID = e.teleportID
    s.grabOffsetX = e.grabOffsetX
    s.grabOffsetY = e.grabOffsetY
    return s
}

func renderFrame() {
    guard let cb = renderCallbacks else { return }
    
    // Draw wind
    for w in wind {
        for i in 0..<w.numExtents {
            cb.drawWindEffect(entities[w.fanEntityIndex].x + Int32(i) * CELL_W, entities[w.fanEntityIndex].y, w.extent(at: i))
        }
    }
    
    // Draw entities
    for e in entities {
        if e.removeBeforeRender { continue }
        if e.type == .levelBounds { continue }
        
        var state = packEntityState(e)
        cb.drawEntity(&state)
    }
    
    // Draw lasers
    for l in laserBeams {
        let e = entities[l.laserEntityIndex]
        cb.drawLaserBeam(e.x, e.y, l.extent, e.facing)
    }
    
    // Draw teleports
    for t in teleportEffects {
        cb.drawTeleportEffect(t.x, t.y, t.frameIndex)
    }
}

// Redirect playSound calls to the callback
func playSound(_ id: SoundID) {
    renderCallbacks?.playSound(id.rawValue)
}

// --- Level loading exports ---

@c public func core_begin_load_level(_ boundsX: Int32, _ boundsY: Int32, _ boundsW: Int32, _ boundsH: Int32) {
    resetLevel()
    if boundsW > 0 && boundsH > 0 {
        initLevelBounds(x: boundsX, y: boundsY, width: boundsW, height: boundsH)
    }
}

@c public func core_add_brick(_ x: Int32, _ y: Int32, _ widthInStuds: Int32, _ colorIndex: Int32, _ fixed: Int32) {
    entities.append(makeBrick(x: x, y: y, widthInStuds: widthInStuds, colorIndex: colorIndex, fixed: fixed != 0))
}

@c public func core_add_junkbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ armored: Int32) {
    entities.append(makeJunkbot(x: x, y: y, facing: facing, armored: armored != 0))
}

@c public func core_add_gearbot(_ x: Int32, _ y: Int32, _ facing: Int32) {
    entities.append(makeGearbot(x: x, y: y, facing: facing))
}

@c public func core_add_climbbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32) {
    entities.append(makeClimbbot(x: x, y: y, facing: facing, facingY: facingY))
}

@c public func core_add_flybot(_ x: Int32, _ y: Int32, _ facing: Int32) {
    entities.append(makeFlybot(x: x, y: y, facing: facing))
}

@c public func core_add_eyebot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32) {
    entities.append(makeEyebot(x: x, y: y, facing: facing, facingY: facingY))
}

@c public func core_add_bin(_ x: Int32, _ y: Int32, _ facing: Int32, _ scaredy: Int32) {
    entities.append(makeBin(x: x, y: y, facing: facing, scaredy: scaredy != 0))
}

@c public func core_add_crate(_ x: Int32, _ y: Int32) {
    entities.append(makeCrate(x: x, y: y))
}

@c public func core_add_fire(_ x: Int32, _ y: Int32, _ on: Int32, _ switchID: Int32) {
    entities.append(makeFire(x: x, y: y, on: on != 0, switchID: switchID))
}

@c public func core_add_fan(_ x: Int32, _ y: Int32, _ on: Int32, _ switchID: Int32) {
    entities.append(makeFan(x: x, y: y, on: on != 0, switchID: switchID))
}

@c public func core_add_switch(_ x: Int32, _ y: Int32, _ on: Int32, _ switchID: Int32) {
    entities.append(makeSwitch(x: x, y: y, on: on != 0, switchID: switchID))
}

@c public func core_add_pipe(_ x: Int32, _ y: Int32) {
    entities.append(makePipe(x: x, y: y))
}

@c public func core_add_shield(_ x: Int32, _ y: Int32, _ used: Int32, _ fixed: Int32) {
    entities.append(makeShield(x: x, y: y, used: used != 0, fixed: fixed != 0))
}

@c public func core_add_jump(_ x: Int32, _ y: Int32, _ fixed: Int32) {
    entities.append(makeJump(x: x, y: y, fixed: fixed != 0))
}

@c public func core_add_teleport(_ x: Int32, _ y: Int32, _ teleportID: Int32) {
    entities.append(makeTeleport(x: x, y: y, teleportID: teleportID))
}

@c public func core_add_laser(_ x: Int32, _ y: Int32, _ facing: Int32, _ on: Int32, _ switchID: Int32) {
    entities.append(makeLaser(x: x, y: y, facing: facing, on: on != 0, switchID: switchID))
}

// --- Input exports ---

@c public func core_mouse_down(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    guard draggingIndices.isEmpty else { return }
    let grabs = possibleGrabsAt(worldX: worldX, worldY: worldY)
    if let first = grabs.first {
        startDrag(entityIndex: first, worldX: worldX, worldY: worldY)
    }
}

@c public func core_mouse_move(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    if !draggingIndices.isEmpty {
        updateDrag(worldX: worldX, worldY: worldY)
    } else {
        hoveredIndices = possibleGrabsAt(worldX: worldX, worldY: worldY)
    }
}

@c public func core_mouse_up(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    if !draggingIndices.isEmpty {
        updateDrag(worldX: worldX, worldY: worldY)
        finishDrag()
    }
}

@c public func core_set_paused(_ isPaused: Bool) {
    paused = isPaused
}

@c public func core_set_viewport(_ cx: Int32, _ cy: Int32, _ scale: Float) {
    viewportCenterX = cx
    viewportCenterY = cy
    viewportScale = scale
}

@c public func core_set_rng_seed(_ seed: UInt32) {
    rngState = seed != 0 ? seed : 1
}

@c public func core_get_win_lose_state() -> Int32 {
    return winLoseState
}

@c public func core_get_viewport(_ cx: UnsafeMutablePointer<Int32>?, _ cy: UnsafeMutablePointer<Int32>?, _ scale: UnsafeMutablePointer<Float>?) {
    cx?.pointee = viewportCenterX
    cy?.pointee = viewportCenterY
    scale?.pointee = viewportScale
}
