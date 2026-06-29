import JavaScriptKit
import JunkbotCoreBridge

nonisolated(unsafe) let window = JSObject.global
_ = window.console.log("Swift: module started")
nonisolated(unsafe) let exports = JSObject.global.Object.function!.new()

exports.game_init = JSClosure { _ in core_init(); return .undefined }.jsValue
exports.game_tick = JSClosure { _ in core_tick(); return .undefined }.jsValue

exports.begin_load_level = JSClosure { args in
    core_begin_load_level(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue
exports.add_brick = JSClosure { args in
    core_add_brick(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!), Int32(args[4].number!))
    return .undefined
}.jsValue
exports.add_junkbot = JSClosure { args in
    core_add_junkbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue
exports.add_gearbot = JSClosure { args in
    core_add_gearbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue
exports.add_climbbot = JSClosure { args in
    core_add_climbbot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue
exports.add_flybot = JSClosure { args in
    core_add_flybot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue
exports.add_eyebot = JSClosure { args in
    core_add_eyebot(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue
exports.add_bin = JSClosure { args in
    core_add_bin(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue
exports.add_crate = JSClosure { args in
    core_add_crate(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue
exports.add_fire = JSClosure { args in
    core_add_fire(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue
exports.add_fan = JSClosure { args in
    core_add_fan(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue
exports.add_switch = JSClosure { args in
    core_add_switch(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue
exports.add_pipe = JSClosure { args in
    core_add_pipe(Int32(args[0].number!), Int32(args[1].number!))
    return .undefined
}.jsValue
exports.add_shield = JSClosure { args in
    core_add_shield(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!))
    return .undefined
}.jsValue
exports.add_jump = JSClosure { args in
    core_add_jump(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue
exports.add_teleport = JSClosure { args in
    core_add_teleport(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!))
    return .undefined
}.jsValue
exports.add_laser = JSClosure { args in
    core_add_laser(Int32(args[0].number!), Int32(args[1].number!), Int32(args[2].number!), Int32(args[3].number!), Int32(args[4].number!))
    return .undefined
}.jsValue

exports.finish_load_level = JSClosure { _ in core_finish_load_level(); return .undefined }.jsValue

exports.mouse_down = JSClosure { args in core_mouse_down(Int32(args[0].number!), Int32(args[1].number!)); return .undefined }.jsValue
exports.mouse_move = JSClosure { args in core_mouse_move(Int32(args[0].number!), Int32(args[1].number!)); return .undefined }.jsValue
exports.mouse_up = JSClosure { args in core_mouse_up(Int32(args[0].number!), Int32(args[1].number!)); return .undefined }.jsValue

exports.set_paused = JSClosure { args in core_set_paused(args[0].boolean!); return .undefined }.jsValue
exports.set_viewport = JSClosure { args in core_set_viewport(Int32(args[0].number!), Int32(args[1].number!), Float(args[2].number!)); return .undefined }.jsValue
exports.set_rng_seed = JSClosure { args in core_set_rng_seed(UInt32(args[0].number!)); return .undefined }.jsValue

window.JunkbotWasm = exports.jsValue
_ = window.console.log("Swift: JunkbotWasm exported, calling onWasmReady")

// Notify JS that Swift is ready
if let ready = window.onWasmReady.function {
    _ = window.console.log("Swift: found onWasmReady, calling it")
    _ = ready()
} else {
    _ = window.console.log("Swift: onWasmReady not found on window!")
}
