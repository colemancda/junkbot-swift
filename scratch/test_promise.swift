import JavaScriptEventLoop
import JavaScriptKit

typealias DefaultExecutorFactory = JavaScriptEventLoop

func test() async throws {
  let fetch = JSObject.global.fetch.function!
  let promise = JSPromise(from: fetch("test"))!
  let res = try await promise.value
  _ = res
}
