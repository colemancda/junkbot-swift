// Rendering — calls to JS draw functions each frame

func renderFrame() {
    jsSetViewport(viewportCenterX, viewportCenterY, viewportScale)
    jsBeginFrame()
    jsClearBackground()

    // Sort entities for rendering: higher y first, then by x
    var renderOrder = Array(0..<entities.count)
    renderOrder.sort { i, j in
        let a = entities[i], b = entities[j]
        if a.y + a.height != b.y + b.height { return a.y + a.height > b.y + b.height }
        return a.x > b.x
    }

    for i in renderOrder {
        renderEntity(index: i)
    }

    // Wind effects (fans)
    for effect in wind {
        let fan = entities[effect.fanEntityIndex]
        var col = 0
        var x = fan.x + CELL_W
        while x < fan.x + fan.width - CELL_W {
            let ext = effect.extent(at: col)
            jsDrawWindColumn(x, fan.y - CELL_H, ext, fan.animationFrame)
            col += 1
            x += CELL_W
        }
    }

    // Laser beams
    for beam in laserBeams {
        let laser = entities[beam.laserEntityIndex]
        let hitWall: Int32 = beam.hitEntityIndex < 0 ? 1 : 0
        jsDrawLaserBeam(laser.x, laser.y, laser.facing, beam.extent, hitWall, laser.animationFrame)
    }

    // Teleport effects
    for effect in teleportEffects {
        jsDrawTeleportEffect(effect.x, effect.y, effect.frameIndex)
    }

    jsEndFrame()
}

private func renderEntity(index: Int) {
    let e = entities[index]
    // Skip entities not yet removed (removal happens after simulate, before next render)
    if e.removeBeforeRender { return }

    switch e.type {
    case .brick:
        jsDrawBrick(e.x, e.y, e.colorIndex, e.widthInStuds, e.fixed ? 1 : 0)

    case .junkbot:
        var flags: Int32 = 0
        if e.armored       { flags |= 1 << 0 }
        if e.dying         { flags |= 1 << 1 }
        if e.dyingFromWater { flags |= 1 << 2 }
        if e.collectingBin { flags |= 1 << 3 }
        if e.floating      { flags |= 1 << 4 }
        if e.losingShield  { flags |= 1 << 5 }
        if e.gettingShield { flags |= 1 << 6 }
        jsDrawJunkbot(e.x, e.y, e.facing, e.animationFrame, flags)

    case .gearbot:
        jsDrawGearbot(e.x, e.y, e.facing, e.animationFrame)

    case .climbbot:
        jsDrawClimbbot(e.x, e.y, e.facing, e.facingY, e.animationFrame)

    case .flybot:
        jsDrawFlybot(e.x, e.y, e.facing, e.animationFrame)

    case .eyebot:
        jsDrawEyebot(e.x, e.y, e.facing, e.facingY, e.animationFrame, 0)

    case .bin:
        jsDrawBin(e.x, e.y, e.facing, e.scaredy ? 1 : 0, e.animationFrame)

    case .crate:
        jsDrawCrate(e.x, e.y)

    case .fire:
        jsDrawFire(e.x, e.y, e.on ? 1 : 0, e.animationFrame)

    case .fan:
        jsDrawFan(e.x, e.y, e.on ? 1 : 0, e.animationFrame)

    case .switch:
        jsDrawSwitch(e.x, e.y, e.on ? 1 : 0, e.animationFrame)

    case .pipe:
        jsDrawPipe(e.x, e.y, e.animationFrame)

    case .shield:
        jsDrawShield(e.x, e.y, e.used ? 1 : 0, e.fixed ? 1 : 0)

    case .jump:
        jsDrawJump(e.x, e.y, e.active ? 1 : 0, e.animationFrame, e.fixed ? 1 : 0)

    case .teleport:
        jsDrawTeleport(e.x, e.y, e.animationFrame, e.blocked ? 1 : 0)

    case .laser:
        jsDrawLaser(e.x, e.y, e.facing, e.on ? 1 : 0)

    case .droplet:
        jsDrawDroplet(e.x, e.y, e.splashing ? 1 : 0, e.animationFrame)

    default:
        break
    }
}
