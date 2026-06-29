import JavaScriptKit
import JunkbotCore

nonisolated(unsafe) let window = JSObject.global

Renderer.setup()

onPlaySound = { soundID in
    _ = Renderer.js.js_play_sound?(soundID)
}

nonisolated(unsafe) let exports = JSObject.global.Object.function!.new()

exports.game_init = JSClosure { _ in
    coreInit()
    return .undefined
}.jsValue

exports.game_tick = JSClosure { _ in
    coreTick()
    Renderer.renderFrame()
    return .undefined
}.jsValue

exports.begin_load_level = JSClosure { args in
    coreBeginLoadLevel(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_brick = JSClosure { args in
    coreAddBrick(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!), args[4].number! != 0)
    return .undefined
}.jsValue

exports.add_junkbot = JSClosure { args in
    coreAddJunkbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), args[3].number! != 0)
    return .undefined
}.jsValue

exports.add_gearbot = JSClosure { args in
    coreAddGearbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue

exports.add_climbbot = JSClosure { args in
    coreAddClimbbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_flybot = JSClosure { args in
    coreAddFlybot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue

exports.add_eyebot = JSClosure { args in
    coreAddEyebot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_bin = JSClosure { args in
    coreAddBin(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), args[3].number! != 0)
    return .undefined
}.jsValue

exports.add_crate = JSClosure { args in
    coreAddCrate(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.add_fire = JSClosure { args in
    coreAddFire(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_fan = JSClosure { args in
    coreAddFan(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_switch = JSClosure { args in
    coreAddSwitch(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, Int32(args[3].number!))
    return .undefined
}.jsValue

exports.add_pipe = JSClosure { args in
    coreAddPipe(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.add_shield = JSClosure { args in
    coreAddShield(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0, args[3].number! != 0)
    return .undefined
}.jsValue

exports.add_jump = JSClosure { args in
    coreAddJump(Int32(args[0].number!), Int32(args[1].number!), args[2].number! != 0)
    return .undefined
}.jsValue

exports.add_teleport = JSClosure { args in
    coreAddTeleport(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue

exports.add_laser = JSClosure { args in
    coreAddLaser(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), args[3].number! != 0, Int32(args[4].number!))
    return .undefined
}.jsValue

exports.finish_load_level = JSClosure { _ in
    coreFinishLoadLevel()
    Renderer.renderFrame()
    return .undefined
}.jsValue

exports.mouse_down = JSClosure { args in
    coreMouseDown(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.mouse_move = JSClosure { args in
    coreMouseMove(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.mouse_up = JSClosure { args in
    coreMouseUp(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue

exports.set_paused = JSClosure { args in
    coreSetPaused(args[0].boolean ?? false)
    return .undefined
}.jsValue

exports.set_viewport = JSClosure { args in
    coreSetViewport(Int32(args[0].number!), Int32(args[1].number!), Float(args[2].number!))
    return .undefined
}.jsValue

exports.set_rng_seed = JSClosure { args in
    coreSetRngSeed(UInt32(args[0].number!))
    return .undefined
}.jsValue

exports.get_win_lose_state = JSClosure { _ in
    return .number(Double(coreGetWinLoseState()))
}.jsValue

window.JunkbotWasm = exports.jsValue

if let ready = window.onWasmReady.function {
    _ = ready()
}
