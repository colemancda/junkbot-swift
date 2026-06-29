import JavaScriptKit
import JunkbotCore

public struct Renderer {
    nonisolated(unsafe) static var js: JSObject!

    public static func setup() {
        js = JSObject.global.JunkbotRenderer.object!
    }

    public static func renderFrame(engine: GameEngine) {
        // Build render list (exclude removed and level-bounds entities)
        var list = engine.entities.filter { !$0.removeBeforeRender && $0.type != .levelBounds }

        // Sort descending by Y: higher Y (lower on screen) drawn first (behind)
        list.sort { $0.y > $1.y }

        // Bubble sort correction matching original game logic:
        // swap adjacent pair when a is entirely above b, or b is entirely left of a
        var n = list.count
        repeat {
            var newN = 0
            for i in 1..<n {
                let a = list[i - 1]
                let b = list[i]
                if a.y + a.height < b.y || b.x + b.width <= a.x {
                    list.swapAt(i - 1, i)
                    newN = i
                }
            }
            n = newN
        } while n > 1

        let grabbedAlpha: Float = engine.canRelease() ? 0.8 : 0.3
        for e in list {
            if e.grabbed { _ = js.js_set_alpha?(grabbedAlpha) }
            drawEntity(e)
            if e.grabbed { _ = js.js_set_alpha?(1.0) }
        }

        // Wind, laser beams, teleport effects always drawn on top of entities
        for w in engine.wind {
            let fan = engine.entities[w.fanEntityIndex]
            for i in 0..<w.numExtents {
                _ = js.js_draw_wind_column?(fan.x + Int32(i) * CELL_W, fan.y, w.extent(at: i), 0)
            }
        }
        for l in engine.laserBeams {
            let e = engine.entities[l.laserEntityIndex]
            _ = js.js_draw_laser_beam?(e.x, e.y, e.facing, l.extent, 0, 0)
        }
        for t in engine.teleportEffects {
            _ = js.js_draw_teleport_effect?(t.x, t.y, t.frameIndex)
        }
    }

    static func drawEntity(_ e: Entity) {
        switch e.type {
        case .brick:
            _ = js.js_draw_brick?(e.x, e.y, e.colorIndex, e.widthInStuds, e.fixed ? 1 : 0)
        case .junkbot:
            var flags: Int32 = 0
            if e.armored        { flags |= 1 }
            if e.dead           { flags |= 2 }
            if e.dyingFromWater { flags |= 4 }
            if e.collectingBin  { flags |= 8 }
            if e.losingShield   { flags |= 32 }
            if e.gettingShield  { flags |= 64 }
            _ = js.js_draw_junkbot?(e.x, e.y, e.facing, e.animationFrame, flags)
        case .gearbot:
            _ = js.js_draw_gearbot?(e.x, e.y, e.facing, e.animationFrame)
        case .climbbot:
            _ = js.js_draw_climbbot?(e.x, e.y, e.facing, e.facingY, e.animationFrame)
        case .flybot:
            _ = js.js_draw_flybot?(e.x, e.y, e.facing, e.animationFrame)
        case .eyebot:
            _ = js.js_draw_eyebot?(e.x, e.y, e.facing, e.facingY, e.animationFrame, 0)
        case .bin:
            _ = js.js_draw_bin?(e.x, e.y, e.facing, e.scaredy ? 1 : 0, e.animationFrame)
        case .crate:
            _ = js.js_draw_crate?(e.x, e.y)
        case .fire:
            _ = js.js_draw_fire?(e.x, e.y, e.on ? 1 : 0, e.animationFrame)
        case .fan:
            _ = js.js_draw_fan?(e.x, e.y, e.on ? 1 : 0, e.animationFrame)
        case .switch:
            _ = js.js_draw_switch?(e.x, e.y, e.on ? 1 : 0, e.animationFrame)
        case .pipe:
            _ = js.js_draw_pipe?(e.x, e.y, e.animationFrame)
        case .shield:
            _ = js.js_draw_shield?(e.x, e.y, e.used ? 1 : 0, e.fixed ? 1 : 0)
        case .jump:
            _ = js.js_draw_jump?(e.x, e.y, e.active ? 1 : 0, e.animationFrame, e.fixed ? 1 : 0)
        case .teleport:
            _ = js.js_draw_teleport?(e.x, e.y, e.animationFrame, e.blocked ? 1 : 0)
        case .laser:
            _ = js.js_draw_laser?(e.x, e.y, e.facing, e.on ? 1 : 0)
        case .droplet:
            _ = js.js_draw_droplet?(e.x, e.y, e.splashing ? 1 : 0, e.animationFrame)
        default:
            break
        }
    }
}
