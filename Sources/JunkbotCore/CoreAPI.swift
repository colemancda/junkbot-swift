// Sound callback — set by JunkbotApp before game starts
public nonisolated(unsafe) var onPlaySound: ((Int32) -> Void)? = nil

func playSound(_ id: SoundID) {
    onPlaySound?(id.rawValue)
}

public func coreInit() {
    rngState = 42
    resetLevel()
}

public func coreTick() {
    guard !paused else { return }
    simulate()
}

public func coreBeginLoadLevel(_ boundsX: Int32, _ boundsY: Int32, _ boundsW: Int32, _ boundsH: Int32) {
    resetLevel()
    if boundsW > 0 && boundsH > 0 {
        initLevelBounds(x: boundsX, y: boundsY, width: boundsW, height: boundsH)
    }
}

public func coreFinishLoadLevel() {
    rebuildAccelerationStructures()
    winLoseState = winOrLose()
}

public func coreAddBrick(_ x: Int32, _ y: Int32, _ widthInStuds: Int32, _ colorIndex: Int32, _ fixed: Bool) {
    entities.append(makeBrick(x: x, y: y, widthInStuds: widthInStuds, colorIndex: colorIndex, fixed: fixed))
}

public func coreAddJunkbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ armored: Bool) {
    entities.append(makeJunkbot(x: x, y: y, facing: facing, armored: armored))
}

public func coreAddGearbot(_ x: Int32, _ y: Int32, _ facing: Int32) {
    entities.append(makeGearbot(x: x, y: y, facing: facing))
}

public func coreAddClimbbot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32) {
    entities.append(makeClimbbot(x: x, y: y, facing: facing, facingY: facingY))
}

public func coreAddFlybot(_ x: Int32, _ y: Int32, _ facing: Int32) {
    entities.append(makeFlybot(x: x, y: y, facing: facing))
}

public func coreAddEyebot(_ x: Int32, _ y: Int32, _ facing: Int32, _ facingY: Int32) {
    entities.append(makeEyebot(x: x, y: y, facing: facing, facingY: facingY))
}

public func coreAddBin(_ x: Int32, _ y: Int32, _ facing: Int32, _ scaredy: Bool) {
    entities.append(makeBin(x: x, y: y, facing: facing, scaredy: scaredy))
}

public func coreAddCrate(_ x: Int32, _ y: Int32) {
    entities.append(makeCrate(x: x, y: y))
}

public func coreAddFire(_ x: Int32, _ y: Int32, _ on: Bool, _ switchID: Int32) {
    entities.append(makeFire(x: x, y: y, on: on, switchID: switchID))
}

public func coreAddFan(_ x: Int32, _ y: Int32, _ on: Bool, _ switchID: Int32) {
    entities.append(makeFan(x: x, y: y, on: on, switchID: switchID))
}

public func coreAddSwitch(_ x: Int32, _ y: Int32, _ on: Bool, _ switchID: Int32) {
    entities.append(makeSwitch(x: x, y: y, on: on, switchID: switchID))
}

public func coreAddPipe(_ x: Int32, _ y: Int32) {
    entities.append(makePipe(x: x, y: y))
}

public func coreAddShield(_ x: Int32, _ y: Int32, _ used: Bool, _ fixed: Bool) {
    entities.append(makeShield(x: x, y: y, used: used, fixed: fixed))
}

public func coreAddJump(_ x: Int32, _ y: Int32, _ fixed: Bool) {
    entities.append(makeJump(x: x, y: y, fixed: fixed))
}

public func coreAddTeleport(_ x: Int32, _ y: Int32, _ teleportID: Int32) {
    entities.append(makeTeleport(x: x, y: y, teleportID: teleportID))
}

public func coreAddLaser(_ x: Int32, _ y: Int32, _ facing: Int32, _ on: Bool, _ switchID: Int32) {
    entities.append(makeLaser(x: x, y: y, facing: facing, on: on, switchID: switchID))
}

public func coreMouseDown(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    guard draggingIndices.isEmpty else { return }
    let grabs = possibleGrabsAt(worldX: worldX, worldY: worldY)
    if let first = grabs.first {
        startDrag(entityIndex: first, worldX: worldX, worldY: worldY)
    }
}

public func coreMouseMove(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    if !draggingIndices.isEmpty {
        updateDrag(worldX: worldX, worldY: worldY)
    } else {
        hoveredIndices = possibleGrabsAt(worldX: worldX, worldY: worldY)
    }
}

public func coreMouseUp(_ worldX: Int32, _ worldY: Int32) {
    mouseWorldX = worldX
    mouseWorldY = worldY
    if !draggingIndices.isEmpty {
        updateDrag(worldX: worldX, worldY: worldY)
        finishDrag()
    }
}

public func coreSetPaused(_ isPaused: Bool) {
    paused = isPaused
}

public func coreSetViewport(_ cx: Int32, _ cy: Int32, _ scale: Float) {
    viewportCenterX = cx
    viewportCenterY = cy
    viewportScale = scale
}

public func coreSetRngSeed(_ seed: UInt32) {
    rngState = seed != 0 ? seed : 1
}

public func coreGetWinLoseState() -> Int32 {
    return winLoseState
}
