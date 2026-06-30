import JavaScriptKit

#if os(WASI)
  nonisolated(unsafe) let window = JSObject.global

  if let objectConstructor = JSObject.global.Object.function,
    let exports = objectConstructor.new().object
  {
    window.JunkbotWasm = exports.jsValue
  }
#endif
