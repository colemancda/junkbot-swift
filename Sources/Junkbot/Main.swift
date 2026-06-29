// Entry point and WebAssembly exports.
// JS calls these functions via the WASM instance.

// Called once when the WASM module is instantiated
@_expose(wasm, "game_init")
@_cdecl("game_init")
public func gameInit() {
    rngState = 42
    resetLevel()
}

// Called by JS every game tick (18fps timer)
@_expose(wasm, "game_tick")
@_cdecl("game_tick")
public func gameTick() {
    guard !paused else { return }
    simulate()
    renderFrame()
}

// Called by JS after all entities are added via add_* functions
@_expose(wasm, "finish_load_level")
@_cdecl("finish_load_level")
public func finishLoadLevel() {
    rebuildAccelerationStructures()
    winLoseState = winOrLose()
    renderFrame()
}

// --- Level loading exports ---

@_expose(wasm, "begin_load_level")
@_cdecl("begin_load_level")
public func beginLoadLevel(
    _ boundsX: Int32, _ boundsY: Int32,
    _ boundsW: Int32, _ boundsH: Int32
) {
    resetLevel()
    if boundsW > 0 && boundsH > 0 {
        initLevelBounds(x: boundsX, y: boundsY, width: boundsW, height: boundsH)
    }
}

@_expose(wasm, "add_brick")
@_cdecl("add_brick")
public func addBrick(
    _ x: Int32, _ y: Int32,
    _ widthInStuds: Int32, _ colorIndex: Int32, _ fixed: Int32
) {
    entities.append(makeBrick(x: x, y: y, widthInStuds: widthInStuds,
                              colorIndex: colorIndex, fixed: fixed != 0))
}

@_expose(wasm, "add_junkbot")
@_cdecl("add_junkbot")
public func addJunkbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ armored: Int32) {
    entities.append(makeJunkbot(x: x, y: y, facing: facing, armored: armored != 0))
}

@_expose(wasm, "add_gearbot")
@_cdecl("add_gearbot")
public func addGearbot(_ x: Int32, _ y: Int32, _ facing: Int32) {
    entities.append(makeGearbot(x: x, y: y, facing: facing))
}

@_expose(wasm, "add_climbbot")
@_cdecl("add_climbbot")
public func addClimbbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32) {
    entities.append(makeClimbbot(x: x, y: y, facing: facing, facingY: facingY))
}

@_expose(wasm, "add_flybot")
@_cdecl("add_flybot")
public func addFlybot(_ x: Int32, _ y: Int32, _ facing: Int32) {
    entities.append(makeFlybot(x: x, y: y, facing: facing))
}

@_expose(wasm, "add_eyebot")
@_cdecl("add_eyebot")
public func addEyebot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32) {
    entities.append(makeEyebot(x: x, y: y, facing: facing, facingY: facingY))
}

@_expose(wasm, "add_bin")
@_cdecl("add_bin")
public func addBin(_ x: Int32, _ y: Int32, _ facing: Int32, _ scaredy: Int32) {
    entities.append(makeBin(x: x, y: y, facing: facing, scaredy: scaredy != 0))
}

@_expose(wasm, "add_crate")
@_cdecl("add_crate")
public func addCrate(_ x: Int32, _ y: Int32) {
    entities.append(makeCrate(x: x, y: y))
}

@_expose(wasm, "add_fire")
@_cdecl("add_fire")
public func addFire(_ x: Int32, _ y: Int32, _ on: Int32, _ switchID: Int32) {
    entities.append(makeFire(x: x, y: y, on: on != 0, switchID: switchID))
}

@_expose(wasm, "add_fan")
@_cdecl("add_fan")
public func addFan(_ x: Int32, _ y: Int32, _ on: Int32, _ switchID: Int32) {
    entities.append(makeFan(x: x, y: y, on: on != 0, switchID: switchID))
}

@_expose(wasm, "add_switch")
@_cdecl("add_switch")
public func addSwitch(_ x: Int32, _ y: Int32, _ on: Int32, _ switchID: Int32) {
    entities.append(makeSwitch(x: x, y: y, on: on != 0, switchID: switchID))
}

@_expose(wasm, "add_pipe")
@_cdecl("add_pipe")
public func addPipe(_ x: Int32, _ y: Int32) {
    entities.append(makePipe(x: x, y: y))
}

@_expose(wasm, "add_shield")
@_cdecl("add_shield")
public func addShield(_ x: Int32, _ y: Int32, _ used: Int32, _ fixed: Int32) {
    entities.append(makeShield(x: x, y: y, used: used != 0, fixed: fixed != 0))
}

@_expose(wasm, "add_jump")
@_cdecl("add_jump")
public func addJump(_ x: Int32, _ y: Int32, _ fixed: Int32) {
    entities.append(makeJump(x: x, y: y, fixed: fixed != 0))
}

@_expose(wasm, "add_teleport")
@_cdecl("add_teleport")
public func addTeleport(_ x: Int32, _ y: Int32, _ teleportID: Int32) {
    entities.append(makeTeleport(x: x, y: y, teleportID: teleportID))
}

@_expose(wasm, "add_laser")
@_cdecl("add_laser")
public func addLaser(_ x: Int32, _ y: Int32, _ facing: Int32, _ on: Int32, _ switchID: Int32) {
    entities.append(makeLaser(x: x, y: y, facing: facing, on: on != 0, switchID: switchID))
}

// --- Input exports ---

@_expose(wasm, "mouse_down")
@_cdecl("mouse_down")
public func mouseDown(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    guard draggingIndices.isEmpty else { return }
    let grabs = possibleGrabsAt(worldX: worldX, worldY: worldY)
    if let first = grabs.first {
        startDrag(entityIndex: first, worldX: worldX, worldY: worldY)
    }
}

@_expose(wasm, "mouse_move")
@_cdecl("mouse_move")
public func mouseMove(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    if !draggingIndices.isEmpty {
        updateDrag(worldX: worldX, worldY: worldY)
    } else {
        hoveredIndices = possibleGrabsAt(worldX: worldX, worldY: worldY)
    }
}

@_expose(wasm, "mouse_up")
@_cdecl("mouse_up")
public func mouseUp(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    if !draggingIndices.isEmpty {
        updateDrag(worldX: worldX, worldY: worldY)
        finishDrag()
    }
}

@_expose(wasm, "set_paused")
@_cdecl("set_paused")
public func setPaused(_ isPaused: Int32) {
    paused = isPaused != 0
}

@_expose(wasm, "set_viewport")
@_cdecl("set_viewport")
public func setViewport(_ cx: Int32, _ cy: Int32, _ scale: Float) {
    viewportCenterX = cx
    viewportCenterY = cy
    viewportScale = scale
}

@_expose(wasm, "set_rng_seed")
@_cdecl("set_rng_seed")
public func setRNGSeed(_ seed: UInt32) {
    rngState = seed != 0 ? seed : 1
}
