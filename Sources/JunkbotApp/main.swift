import JavaScriptKit
import JunkbotCore

nonisolated(unsafe) let window = JSObject.global
_ = window.console.log("Swift: module started")
let exports = JSObject.global.Object.function!.new()
let engine = GameEngine()
let document = window.document.object!

// Removed Renderer setup

exports.game_init =
    JSClosure { _ in
        engine.initialize()
        return .undefined
    }.jsValue

exports.rectanglesIntersect =
    JSClosure { args in
        let ax = args[0].number ?? 0
        let ay = args[1].number ?? 0
        let aw = args[2].number ?? 0
        let ah = args[3].number ?? 0

        let bx = args[4].number ?? 0
        let by = args[5].number ?? 0
        let bw = args[6].number ?? 0
        let bh = args[7].number ?? 0

        let intersects = ax + aw > bx && ax < bx + bw && ay + ah > by && ay < by + bh

        return .boolean(intersects)
    }.jsValue

exports.rectangleLevelBoundsCollisionTest =
    JSClosure { args in
        let x = Int32(args[0].number ?? 0)
        let y = Int32(args[1].number ?? 0)
        let width = Int32(args[2].number ?? 0)
        let height = Int32(args[3].number ?? 0)

        if let entity = engine.rectangleLevelBoundsCollision(x: x, y: y, width: width, height: height) {
            let obj = JSObject.global.Object.function!.new()
            obj.type = "levelBounds".jsValue
            obj.x = entity.x.jsValue
            obj.y = entity.y.jsValue
            obj.width = entity.width.jsValue
            obj.height = entity.height.jsValue
            return obj.jsValue
        }
        return .undefined
    }.jsValue

window.JunkbotWasm = exports.jsValue
_ = window.console.log("Swift: JunkbotWasm exported")

// Notify JS that Swift is ready, but also load game.js first so that the DOM is intact.
// Actually, game.js is loaded dynamically if we inject it here.
let script = document.createElement!("script").object!
script.src = "src/game.js"
script.onload =
    JSClosure { _ in
        if let ready = window.onWasmReady.function {
            _ = window.console.log("Swift: found onWasmReady, calling it")
            _ = ready()
        }
        return .undefined
    }.jsValue
_ = document.body.object!.appendChild!(script)
