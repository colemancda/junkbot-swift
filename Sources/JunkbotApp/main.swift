import JavaScriptKit
import JunkbotCore

nonisolated(unsafe) let window = JSObject.global
nonisolated(unsafe) let engine = GameEngine()

Renderer.setup()
engine.onPlaySound = { soundID in
    _ = Renderer.js.js_play_sound?(soundID)
}

nonisolated(unsafe) let exports = JSObject.global.Object.function!.new()

exports.game_init = JSClosure { _ in
    engine.coreInit()
    return .undefined
}.jsValue

exports.game_tick = JSClosure { _ in
    engine.coreTick()
    Renderer.renderFrame(engine: engine)
    return .undefined
}.jsValue

exports.begin_load_level = JSClosure { args in
    engine.coreBeginLoadLevel(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_brick = JSClosure { args in
    engine.coreAddBrick(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!), args[4].number! != 0)
    return .undefined
}.jsValue

exports.add_junkbot = JSClosure { args in
    engine.coreAddJunkbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), args[3].number! != 0)
    return .undefined
}.jsValue

exports.add_gearbot = JSClosure { args in
    engine.coreAddGearbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue

exports.add_climbbot = JSClosure { args in
    engine.coreAddClimbbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_flybot = JSClosure { args in
    engine.coreAddFlybot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue

exports.add_eyebot = JSClosure { args in
    engine.coreAddEyebot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_bin = JSClosure { args in
    engine.coreAddBin(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), args[3].number! != 0)
    return .undefined
}.jsValue

exports.add_crate = JSClosure { args in
    engine.coreAddCrate(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.add_fire = JSClosure { args in
    engine.coreAddFire(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_fan = JSClosure { args in
    engine.coreAddFan(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_switch = JSClosure { args in
    engine.coreAddSwitch(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_pipe = JSClosure { args in
    engine.coreAddPipe(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.add_shield = JSClosure { args in
    engine.coreAddShield(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, args[3].number! != 0)
    return .undefined
}.jsValue

exports.add_jump = JSClosure { args in
    engine.coreAddJump(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0)
    return .undefined
}.jsValue

exports.add_teleport = JSClosure { args in
    engine.coreAddTeleport(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue

exports.add_laser = JSClosure { args in
    engine.coreAddLaser(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), args[3].number! != 0, Int32(args[4].number!))
    return .undefined
}.jsValue

exports.finish_load_level = JSClosure { _ in
    engine.coreFinishLoadLevel()
    Renderer.renderFrame(engine: engine)
    return .undefined
}.jsValue

exports.mouse_down = JSClosure { args in
    engine.coreMouseDown(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.mouse_move = JSClosure { args in
    engine.coreMouseMove(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.mouse_up = JSClosure { args in
    engine.coreMouseUp(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.set_paused = JSClosure { args in
    engine.coreSetPaused(args[0].boolean ?? false)
    return .undefined
}.jsValue

exports.set_viewport = JSClosure { args in
    engine.coreSetViewport(Int32(args[0].number!), Int32(args[1].number!), Float(args[2].number!))
    return .undefined
}.jsValue

exports.set_rng_seed = JSClosure { args in
    engine.coreSetRngSeed(UInt32(args[0].number!))
    return .undefined
}.jsValue

exports.get_win_lose_state = JSClosure { _ in
    return .number(Double(engine.coreGetWinLoseState()))
}.jsValue

window.JunkbotWasm = exports.jsValue

if let ready = window.onWasmReady.function {
    _ = ready()
}
