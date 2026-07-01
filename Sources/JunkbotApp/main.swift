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
        let ax = Int32(args[0].number ?? 0)
        let ay = Int32(args[1].number ?? 0)
        let aw = Int32(args[2].number ?? 0)
        let ah = Int32(args[3].number ?? 0)

        let bx = Int32(args[4].number ?? 0)
        let by = Int32(args[5].number ?? 0)
        let bw = Int32(args[6].number ?? 0)
        let bh = Int32(args[7].number ?? 0)

        let intersects = engine.rectanglesIntersect(ax, ay, aw, ah, bx, by, bw, bh)

        return .boolean(intersects)
    }.jsValue

func rectangleLevelBoundsCollisionObject(x: Int32, y: Int32, width: Int32, height: Int32) -> JSValue? {
    guard let entity = engine.rectangleLevelBoundsCollision(x: x, y: y, width: width, height: height) else {
        return nil
    }
    let obj = JSObject.global.Object.function!.new()
    obj.type = "levelBounds".jsValue
    obj.x = entity.x.jsValue
    obj.y = entity.y.jsValue
    obj.width = entity.width.jsValue
    obj.height = entity.height.jsValue
    return obj.jsValue
}

func rectangleCollision(
    x: Int32, y: Int32, width: Int32, height: Int32,
    filter: JSObject, entities: JSObject
) -> JSValue? {
    if let bounds = rectangleLevelBoundsCollisionObject(x: x, y: y, width: width, height: height),
        filter(bounds).boolean == true
    {
        return bounds
    }
    let length = Int(entities.length.number ?? 0)
    for i in 0..<length {
        let other = entities[i]
        guard let otherObj = other.object else { continue }
        if otherObj.grabbed.boolean == true { continue }
        guard filter(other).boolean == true else { continue }
        let ox = Int32(otherObj.x.number ?? 0)
        let oy = Int32(otherObj.y.number ?? 0)
        let ow = Int32(otherObj.width.number ?? 0)
        let oh = Int32(otherObj.height.number ?? 0)
        if engine.rectanglesIntersect(x, y, width, height, ox, oy, ow, oh) {
            return other
        }
    }
    return nil
}

func rectangleCollisionAll(
    x: Int32, y: Int32, width: Int32, height: Int32,
    filter: JSObject, entities: JSObject
) -> [JSValue] {
    var result: [JSValue] = []
    if let bounds = rectangleLevelBoundsCollisionObject(x: x, y: y, width: width, height: height),
        filter(bounds).boolean == true
    {
        result.append(bounds)
    }
    let length = Int(entities.length.number ?? 0)
    for i in 0..<length {
        let other = entities[i]
        guard let otherObj = other.object else { continue }
        if otherObj.grabbed.boolean == true { continue }
        guard filter(other).boolean == true else { continue }
        let ox = Int32(otherObj.x.number ?? 0)
        let oy = Int32(otherObj.y.number ?? 0)
        let ow = Int32(otherObj.width.number ?? 0)
        let oh = Int32(otherObj.height.number ?? 0)
        if engine.rectanglesIntersect(x, y, width, height, ox, oy, ow, oh) {
            result.append(other)
        }
    }
    return result
}

exports.rectangleLevelBoundsCollisionTest =
    JSClosure { args in
        let x = Int32(args[0].number ?? 0)
        let y = Int32(args[1].number ?? 0)
        let width = Int32(args[2].number ?? 0)
        let height = Int32(args[3].number ?? 0)
        return rectangleLevelBoundsCollisionObject(x: x, y: y, width: width, height: height) ?? .undefined
    }.jsValue

exports.rectangleCollisionTest =
    JSClosure { args in
        let x = Int32(args[0].number ?? 0)
        let y = Int32(args[1].number ?? 0)
        let width = Int32(args[2].number ?? 0)
        let height = Int32(args[3].number ?? 0)
        guard let filter = args[4].function, let entities = args[5].object else { return .null }

        return rectangleCollision(x: x, y: y, width: width, height: height, filter: filter, entities: entities)
            ?? .null
    }.jsValue

exports.rectangleCollisionAll =
    JSClosure { args in
        let x = Int32(args[0].number ?? 0)
        let y = Int32(args[1].number ?? 0)
        let width = Int32(args[2].number ?? 0)
        let height = Int32(args[3].number ?? 0)
        guard let filter = args[4].function, let entities = args[5].object else { return [JSValue]().jsValue }

        return rectangleCollisionAll(x: x, y: y, width: width, height: height, filter: filter, entities: entities)
            .jsValue
    }.jsValue

exports.raycast =
    JSClosure { args in
        let startX = Int32(args[0].number ?? 0)
        let startY = Int32(args[1].number ?? 0)
        let width = Int32(args[2].number ?? 0)
        let height = Int32(args[3].number ?? 0)
        let directionX = Int32(args[4].number ?? 0)
        let directionY = Int32(args[5].number ?? 0)
        let maxSteps = Int32(args[6].number ?? 0)
        guard let filter = args[7].function, let entities = args[8].object else { return .undefined }
        let onStep = args[9].function

        var x = startX
        var y = startY
        var steps: Int32 = 0
        let result = JSObject.global.Object.function!.new()
        while steps < maxSteps {
            x += CELL_W * directionX
            y += CELL_H * directionY
            _ = onStep?(x, y, width, height)
            if let hit = rectangleCollision(x: x, y: y, width: width, height: height, filter: filter, entities: entities) {
                result.steps = Double(steps).jsValue
                result.hit = hit
                return result.jsValue
            }
            steps += 1
        }
        result.steps = Double(steps).jsValue
        result.hit = .null
        return result.jsValue
    }.jsValue

exports.sortEntitiesForRendering =
    JSClosure { args in
        guard let array = args[0].object else { return .undefined }
        let length = Int(array.length.number ?? 0)
        guard length > 1 else { return .undefined }

        let elements = (0..<length).map { array[$0] }
        let boxes = elements.map { element -> RenderBox in
            let obj = element.object!
            return RenderBox(
                x: obj.x.number ?? 0,
                y: obj.y.number ?? 0,
                width: obj.width.number ?? 0,
                height: obj.height.number ?? 0
            )
        }

        let order = sortOrderForRendering(boxes)
        for i in 0..<length {
            array[i] = elements[order[i]]
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
