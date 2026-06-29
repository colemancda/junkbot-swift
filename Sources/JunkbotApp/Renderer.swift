import JavaScriptKit
import JunkbotCoreBridge

struct Renderer {
    nonisolated(unsafe) static var jsRenderer: JSObject!
    
    static func setup() {
        jsRenderer = JSObject.global.JunkbotRenderer.object!
        
        var callbacks = JunkbotRenderCallbacks()
        
        // We only need to fetch functions if they're used.
        // Actually, we can just call them directly via jsRenderer dynamically.
        callbacks.drawEntity = { state in
            guard let s = state?.pointee else { return }
            let type = s.type
            // switch on EntityType rawValue (type)
            switch type {
            case 17: // levelBounds
                break
            case 0: // brick
                _ = Renderer.jsRenderer.js_draw_brick?(s.x, s.y, s.colorIndex, s.widthInStuds, s.fixed ? 1 : 0)
            case 1: // junkbot
                var flags: Int32 = 0
                if s.armored { flags |= 1 }
                if s.dead { flags |= 2 }
                if s.splashing { flags |= 4 } // dyingFromWater
                if s.collectingBin { flags |= 8 }
                if s.losingShield { flags |= 32 }
                if s.gettingShield { flags |= 64 }
                _ = Renderer.jsRenderer.js_draw_junkbot?(s.x, s.y, s.facing, s.animationFrame, flags)
            case 2: // gearbot
                _ = Renderer.jsRenderer.js_draw_gearbot?(s.x, s.y, s.facing, s.animationFrame)
            case 3: // climbbot
                _ = Renderer.jsRenderer.js_draw_climbbot?(s.x, s.y, s.facing, s.facingY, s.animationFrame)
            case 4: // flybot
                _ = Renderer.jsRenderer.js_draw_flybot?(s.x, s.y, s.facing, s.animationFrame)
            case 5: // eyebot
                _ = Renderer.jsRenderer.js_draw_eyebot?(s.x, s.y, s.facing, s.facingY, s.animationFrame, 0)
            case 6: // bin
                _ = Renderer.jsRenderer.js_draw_bin?(s.x, s.y, s.facing, s.scaredy ? 1 : 0, s.animationFrame)
            case 7: // crate
                _ = Renderer.jsRenderer.js_draw_crate?(s.x, s.y)
            case 8: // fire
                _ = Renderer.jsRenderer.js_draw_fire?(s.x, s.y, s.on ? 1 : 0, s.animationFrame)
            case 9: // fan
                _ = Renderer.jsRenderer.js_draw_fan?(s.x, s.y, s.on ? 1 : 0, s.animationFrame)
            case 10: // switch
                _ = Renderer.jsRenderer.js_draw_switch?(s.x, s.y, s.on ? 1 : 0, s.animationFrame)
            case 11: // pipe
                _ = Renderer.jsRenderer.js_draw_pipe?(s.x, s.y, s.animationFrame)
            case 12: // shield
                _ = Renderer.jsRenderer.js_draw_shield?(s.x, s.y, s.used ? 1 : 0, s.fixed ? 1 : 0)
            case 15: // jump
                _ = Renderer.jsRenderer.js_draw_jump?(s.x, s.y, s.active ? 1 : 0, s.animationFrame, s.fixed ? 1 : 0)
            case 13: // teleport
                _ = Renderer.jsRenderer.js_draw_teleport?(s.x, s.y, s.animationFrame, s.blocked ? 1 : 0)
            case 14: // laser
                _ = Renderer.jsRenderer.js_draw_laser?(s.x, s.y, s.facing, s.on ? 1 : 0)
            case 16: // droplet
                _ = Renderer.jsRenderer.js_draw_droplet?(s.x, s.y, s.splashing ? 1 : 0, s.animationFrame)
            default: break
            }
        }
        
        callbacks.drawWindEffect = { x, y, extent in
            _ = Renderer.jsRenderer.js_draw_wind_column?(x, y, extent, 0)
        }
        
        callbacks.drawLaserBeam = { x, y, extent, facing in
            _ = Renderer.jsRenderer.js_draw_laser_beam?(x, y, facing, extent, 0, 0) // need animFrame?
        }
        
        callbacks.drawTeleportEffect = { x, y, frame in
            _ = Renderer.jsRenderer.js_draw_teleport_effect?(x, y, frame)
        }
        
        callbacks.playSound = { soundID in
            _ = Renderer.jsRenderer.js_play_sound?(soundID)
        }
        
        core_set_render_callbacks(callbacks)
    }
}
