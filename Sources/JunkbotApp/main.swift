import JavaScriptKit

let window = JSObject.global
let document = window.document.object!

let exports = JSObject.global.Object.function!.new()

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

let script = document.createElement!("script").object!
script.src = "src/game.js"
_ = document.body.object!.appendChild!(script)

print("WASM successfully injected game.js")
