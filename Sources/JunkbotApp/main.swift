import JavaScriptKit
import JunkbotCore

nonisolated(unsafe) let window = JSObject.global
_ = window.console.log("Swift: module started")
let exports = JSObject.global.Object.function!.new()
let engine = GameEngine()
let document = window.document.object!

// Removed Renderer setup

exports.game_init = JSClosure { _ in
    engine.initialize()
    return .undefined
}.jsValue

func syncToJS() {

    if let syncStart = window.sync_entities_start.function {
        _ = syncStart(engine.entities.count)
        
        if window.sync_entity_1.function != nil {
            for (i, e) in engine.entities.enumerated() {
                var flags: Int32 = 0
                if e.grabbed { flags |= 1 << 0 }
                if e.fixed { flags |= 1 << 1 }
                if e.floating { flags |= 1 << 2 }
                if e.wasFloating { flags |= 1 << 3 }
                if e.removeBeforeRender { flags |= 1 << 4 }
                if e.armored { flags |= 1 << 5 }
                if e.losingShield { flags |= 1 << 6 }
                if e.gettingShield { flags |= 1 << 7 }
                if e.dying { flags |= 1 << 8 }
                if e.dyingFromWater { flags |= 1 << 9 }
                if e.dead { flags |= 1 << 10 }
                if e.collectingBin { flags |= 1 << 11 }
                if e.headLoaded { flags |= 1 << 12 }
                if e.scaredy { flags |= 1 << 13 }
                if e.on { flags |= 1 << 14 }
                if e.used { flags |= 1 << 15 }
                if e.blocked { flags |= 1 << 16 }
                if e.active { flags |= 1 << 17 }
                if e.splashing { flags |= 1 << 18 }
                
                if let syncEntity1 = window.sync_entity_1.function,
                   let syncEntity2 = window.sync_entity_2.function,
                   let syncEntity3 = window.sync_entity_3.function {
                    
                    _ = syncEntity1(Int32(i), e.id, Int32(e.type.rawValue), e.x, e.y, e.width, e.height)
                    _ = syncEntity2(Int32(i), e.facing, e.facingY, e.animationFrame, e.widthInStuds, e.colorIndex, e.switchID)
                    _ = syncEntity3(Int32(i), e.teleportID, e.timer, e.activeTimer, flags)
                }
            }
        }
        
        if let syncWindStart = window.sync_wind_start.function {
            _ = syncWindStart(engine.wind.count)
            if let syncWind1 = window.sync_wind_1.function, let syncWind2 = window.sync_wind_2.function {
                for (i, w) in engine.wind.enumerated() {
                    _ = syncWind1(Int32(i), Int32(w.fanEntityIndex), Int32(w.numExtents), w.extent(at: 0), w.extent(at: 1), w.extent(at: 2))
                    _ = syncWind2(Int32(i), w.extent(at: 3), w.extent(at: 4), w.extent(at: 5), w.extent(at: 6), w.extent(at: 7))
                }
            }
        }
        
        if let syncLasersStart = window.sync_lasers_start.function {
            _ = syncLasersStart(engine.laserBeams.count)
            if let syncLasers = window.sync_lasers.function {
                for (i, l) in engine.laserBeams.enumerated() {
                    _ = syncLasers(Int32(i), Int32(l.laserEntityIndex), l.extent, Int32(l.hitEntityIndex))
                }
            }
        }
        
        if let syncTeleportEffectsStart = window.sync_teleport_effects_start.function {
            _ = syncTeleportEffectsStart(engine.teleportEffects.count)
            if let syncTeleportEffects = window.sync_teleport_effects.function {
                for (i, t) in engine.teleportEffects.enumerated() {
                    _ = syncTeleportEffects(Int32(i), t.x, t.y, t.frameIndex)
                }
            }
        }
    }
}

exports.game_tick = JSClosure { _ in
    engine.tick()
    syncToJS()
    return .undefined
}.jsValue

exports.begin_load_level = JSClosure { args in
    let bx = Int32(args[0].number!)
    let by = Int32(args[1].number!)
    let bw = Int32(args[2].number!)
    let bh = Int32(args[3].number!)
    engine.beginLoadLevel(bx, by, bw, bh)
    return .undefined
}.jsValue

exports.add_brick = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let w = Int32(args[2].number!)
    let c = Int32(args[3].number!)
    let f = args[4].number! != 0
    engine.addBrick(x, y, w, c, f)
    return .undefined
}.jsValue

exports.add_junkbot = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let f = Int32(args[2].number!)
    let a = args[3].number! != 0
    engine.addJunkbot(x, y, f, a)
    return .undefined
}.jsValue

exports.add_gearbot = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let f = Int32(args[2].number!)
    engine.addGearbot(x, y, f)
    return .undefined
}.jsValue

exports.add_climbbot = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let f = Int32(args[2].number!)
    let fy = Int32(args[3].number!)
    engine.addClimbbot(x, y, f, fy)
    return .undefined
}.jsValue

exports.add_flybot = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let f = Int32(args[2].number!)
    engine.addFlybot(x, y, f)
    return .undefined
}.jsValue

exports.add_eyebot = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let f = Int32(args[2].number!)
    let fy = Int32(args[3].number!)
    engine.addEyebot(x, y, f, fy)
    return .undefined
}.jsValue

exports.add_bin = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let f = Int32(args[2].number!)
    let s = args[3].number! != 0
    engine.addBin(x, y, f, s)
    return .undefined
}.jsValue

exports.add_crate = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    engine.addCrate(x, y)
    return .undefined
}.jsValue

exports.add_fire = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let on = args[2].number! != 0
    let sid = Int32(args[3].number!)
    engine.addFire(x, y, on, sid)
    return .undefined
}.jsValue

exports.add_fan = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let on = args[2].number! != 0
    let sid = Int32(args[3].number!)
    engine.addFan(x, y, on, sid)
    return .undefined
}.jsValue

exports.add_switch = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let on = args[2].number! != 0
    let sid = Int32(args[3].number!)
    engine.addSwitch(x, y, on, sid)
    return .undefined
}.jsValue

exports.add_pipe = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    engine.addPipe(x, y)
    return .undefined
}.jsValue

exports.add_shield = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let used = args[2].number! != 0
    let f = args[3].number! != 0
    engine.addShield(x, y, used, f)
    return .undefined
}.jsValue

exports.add_jump = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let f = args[2].number! != 0
    engine.addJump(x, y, f)
    return .undefined
}.jsValue

exports.add_teleport = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let tid = Int32(args[2].number!)
    engine.addTeleport(x, y, tid)
    return .undefined
}.jsValue

exports.add_laser = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    let f = Int32(args[2].number!)
    let on = args[3].number! != 0
    let sid = Int32(args[4].number!)
    engine.addLaser(x, y, f, on, sid)
    return .undefined
}.jsValue

exports.finish_load_level = JSClosure { _ in
    engine.finishLoadLevel()
    syncToJS()
    return .undefined
}.jsValue

exports.mouse_down = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    engine.mouseDown(x, y)
    return .undefined
}.jsValue

exports.mouse_move = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    engine.mouseMove(x, y)
    return .undefined
}.jsValue

exports.mouse_up = JSClosure { args in
    let x = Int32(args[0].number!)
    let y = Int32(args[1].number!)
    engine.mouseUp(x, y)
    return .undefined
}.jsValue

exports.set_paused = JSClosure { args in
    let p = args[0].boolean!
    engine.setPaused(p)
    return .undefined
}.jsValue

exports.set_viewport = JSClosure { args in
    let cx = Int32(args[0].number!)
    let cy = Int32(args[1].number!)
    let scale = Float(args[2].number!)
    engine.setViewport(cx, cy, scale)
    return .undefined
}.jsValue

exports.set_rng_seed = JSClosure { args in
    if let js_rng = args[0].function {
        engine.rng = {
            return Float(js_rng().number!)
        }
    } else if let num = args[0].number {
        var state = UInt32(num)
        engine.rng = {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return Float(state & 0x7FFF_FFFF) / Float(0x7FFF_FFFF)
        }
    }
    return .undefined
}.jsValue

exports.get_win_lose_state = JSClosure { _ in
    return .number(Double(engine.winLoseState))
}.jsValue

exports.get_level_title = JSClosure { _ in
    return .string(engine.levelTitle)
}.jsValue

exports.get_level_hint = JSClosure { _ in
    return .string(engine.levelHint)
}.jsValue

exports.get_level_par = JSClosure { _ in
    let par = engine.levelPar
    if par == Int.max { return .null }
    return .number(Double(par))
}.jsValue

exports.set_level_info = JSClosure { args in
    if let title = args[0].string {
        engine.levelTitle = title
    }
    if let hint = args[1].string {
        engine.levelHint = hint
    }
    if let par = args[2].number {
        engine.levelPar = Int(par)
    }
    return .undefined
}.jsValue

exports.rectanglesIntersect = JSClosure { args in
    let ax = args[0].number ?? 0
    let ay = args[1].number ?? 0
    let aw = args[2].number ?? 0
    let ah = args[3].number ?? 0
    
    let bx = args[4].number ?? 0
    let by = args[5].number ?? 0
    let bw = args[6].number ?? 0
    let bh = args[7].number ?? 0
    
    let intersects = ax + aw > bx &&
                     ax < bx + bw &&
                     ay + ah > by &&
                     ay < by + bh
                     
    return .boolean(intersects)
}.jsValue


window.JunkbotWasm = exports.jsValue
_ = window.console.log("Swift: JunkbotWasm exported")

// Notify JS that Swift is ready, but also load game.js first so that the DOM is intact.
// Actually, game.js is loaded dynamically if we inject it here.
let script = document.createElement!("script").object!
script.src = "src/game.js"
script.onload = JSClosure { _ in
    if let ready = window.onWasmReady.function {
        _ = window.console.log("Swift: found onWasmReady, calling it")
        _ = ready()
    }
    return .undefined
}.jsValue
_ = document.body.object!.appendChild!(script)
