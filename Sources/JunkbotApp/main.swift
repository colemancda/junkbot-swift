import JavaScriptKit
import JunkbotCore

nonisolated(unsafe) let window = JSObject.global
nonisolated(unsafe) let engine = GameEngine()

Renderer.setup()

nonisolated(unsafe) let mathRandom = JSObject.global.Math.object!.random.function!
engine.rng = { Float(mathRandom().number!) }
engine.onPlaySound = { soundID in
    _ = Renderer.js.js_play_sound?(soundID)
}

nonisolated(unsafe) let exports = JSObject.global.Object.function!.new()

exports.game_init = JSClosure { _ in
    engine.initialize()
    return .undefined
}.jsValue

exports.game_tick = JSClosure { _ in
    engine.tick()
    Renderer.renderFrame(engine: engine)
    return .undefined
}.jsValue

exports.begin_load_level = JSClosure { args in
    engine.beginLoadLevel(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_brick = JSClosure { args in
    engine.addBrick(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!), args[4].number! != 0)
    return .undefined
}.jsValue

exports.add_junkbot = JSClosure { args in
    engine.addJunkbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), args[3].number! != 0)
    return .undefined
}.jsValue

exports.add_gearbot = JSClosure { args in
    engine.addGearbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue

exports.add_climbbot = JSClosure { args in
    engine.addClimbbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_flybot = JSClosure { args in
    engine.addFlybot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue

exports.add_eyebot = JSClosure { args in
    engine.addEyebot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_bin = JSClosure { args in
    engine.addBin(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), args[3].number! != 0)
    return .undefined
}.jsValue

exports.add_crate = JSClosure { args in
    engine.addCrate(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.add_fire = JSClosure { args in
    engine.addFire(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_fan = JSClosure { args in
    engine.addFan(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_switch = JSClosure { args in
    engine.addSwitch(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_pipe = JSClosure { args in
    engine.addPipe(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.add_shield = JSClosure { args in
    engine.addShield(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, args[3].number! != 0)
    return .undefined
}.jsValue

exports.add_jump = JSClosure { args in
    engine.addJump(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0)
    return .undefined
}.jsValue

exports.add_teleport = JSClosure { args in
    engine.addTeleport(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue

exports.add_laser = JSClosure { args in
    engine.addLaser(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), args[3].number! != 0, Int32(args[4].number!))
    return .undefined
}.jsValue

exports.finish_load_level = JSClosure { _ in
    engine.finishLoadLevel()
    Renderer.renderFrame(engine: engine)
    return .undefined
}.jsValue

exports.mouse_down = JSClosure { args in
    engine.mouseDown(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.mouse_move = JSClosure { args in
    engine.mouseMove(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.mouse_up = JSClosure { args in
    engine.mouseUp(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.set_paused = JSClosure { args in
    engine.setPaused(args[0].boolean ?? false)
    return .undefined
}.jsValue

exports.set_viewport = JSClosure { args in
    engine.setViewport(Int32(args[0].number!), Int32(args[1].number!), Float(args[2].number!))
    return .undefined
}.jsValue

exports.get_win_lose_state = JSClosure { _ in
    return .number(Double(engine.winLose()))
}.jsValue

window.JunkbotWasm = exports.jsValue

if let ready = window.onWasmReady.function {
    _ = ready()
}
