import JavaScriptKit

let window = JSObject.global
let document = window.document.object!

let script = document.createElement!("script").object!
script.src = "game.js"
_ = document.body.object!.appendChild!(script)

print("WASM successfully injected game.js")
