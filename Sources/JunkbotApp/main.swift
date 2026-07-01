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

func makeEntityBase(id: JSValue, type: String, x: JSValue, y: JSValue, width: Int32, height: Int32) -> JSObject {
    let obj = JSObject.global.Object.function!.new()
    obj.id = id
    obj.type = type.jsValue
    obj.x = x
    obj.y = y
    obj.width = width.jsValue
    obj.height = height.jsValue
    return obj
}

exports.makeBrick =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let widthInStuds = args[3]
        let colorName = args[4]
        let fixed = args[5]

        let obj = makeEntityBase(
            id: id, type: "brick", x: x, y: y,
            width: Int32(widthInStuds.number ?? 0) * CELL_W, height: CELL_H)
        obj.widthInStuds = widthInStuds
        obj.colorName = colorName
        obj.fixed = fixed
        return obj.jsValue
    }.jsValue

exports.makeJunkbot =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let facing = args[3]
        let armored = args[4]

        let obj = makeEntityBase(id: id, type: "junkbot", x: x, y: y, width: 2 * CELL_W, height: 4 * CELL_H)
        obj.facing = facing
        obj.armored = armored
        obj.losingShield = .boolean(false)
        obj.losingShieldTime = .number(0)
        obj.animationFrame = .number(0)
        obj.headLoaded = .boolean(false)
        return obj.jsValue
    }.jsValue

exports.makeGearbot =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let facing = args[3]

        let obj = makeEntityBase(id: id, type: "gearbot", x: x, y: y, width: 2 * CELL_W, height: 2 * CELL_H)
        obj.facing = facing
        obj.animationFrame = .number(0)
        return obj.jsValue
    }.jsValue

exports.makeClimbbot =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let facing = args[3]
        let facingY = args[4]

        let obj = makeEntityBase(id: id, type: "climbbot", x: x, y: y, width: 2 * CELL_W, height: 2 * CELL_H)
        obj.facing = facing
        obj.facingY = facingY
        obj.animationFrame = .number(0)
        obj.energy = .number(0)
        return obj.jsValue
    }.jsValue

exports.makeFlybot =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let facing = args[3]

        let obj = makeEntityBase(id: id, type: "flybot", x: x, y: y, width: 2 * CELL_W, height: 2 * CELL_H)
        obj.facing = facing
        obj.animationFrame = .number(0)
        return obj.jsValue
    }.jsValue

exports.makeEyebot =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let facing = args[3]
        let facingY = args[4]

        let obj = makeEntityBase(id: id, type: "eyebot", x: x, y: y, width: 2 * CELL_W, height: 2 * CELL_H)
        obj.facing = facing
        obj.facingY = facingY
        obj.animationFrame = .number(0)
        return obj.jsValue
    }.jsValue

exports.makeBin =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let facing = args[3]
        let scaredy = args[4]

        let obj = makeEntityBase(id: id, type: "bin", x: x, y: y, width: 2 * CELL_W, height: 3 * CELL_H)
        obj.facing = facing
        obj.scaredy = scaredy
        obj.animationFrame = .number(0)
        return obj.jsValue
    }.jsValue

exports.makeCrate =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]

        let obj = makeEntityBase(id: id, type: "crate", x: x, y: y, width: 3 * CELL_W, height: 2 * CELL_H)
        return obj.jsValue
    }.jsValue

exports.makeFire =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let on = args[3]
        let switchID = args[4]

        let obj = makeEntityBase(id: id, type: "fire", x: x, y: y, width: 4 * CELL_W, height: 1 * CELL_H)
        obj.on = on
        obj.switchID = switchID
        obj.animationFrame = .number(0)
        obj.fixed = .boolean(true)
        return obj.jsValue
    }.jsValue

exports.makeFan =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let on = args[3]
        let switchID = args[4]

        let obj = makeEntityBase(id: id, type: "fan", x: x, y: y, width: 4 * CELL_W, height: 1 * CELL_H)
        obj.on = on
        obj.switchID = switchID
        obj.animationFrame = .number(0)
        obj.fixed = .boolean(true)
        return obj.jsValue
    }.jsValue

exports.makeLaser =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let on = args[3]
        let switchID = args[4]
        let facing = args[5]

        let obj = makeEntityBase(id: id, type: "laser", x: x, y: y, width: 2 * CELL_W, height: 1 * CELL_H)
        obj.on = on
        obj.switchID = switchID
        obj.animationFrame = .number(0)
        obj.facing = facing
        obj.fixed = .boolean(true)
        return obj.jsValue
    }.jsValue

exports.makeSwitch =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let on = args[3]
        let switchID = args[4]

        let obj = makeEntityBase(id: id, type: "switch", x: x, y: y, width: 2 * CELL_W, height: 1 * CELL_H)
        obj.on = on
        obj.switchID = switchID
        obj.fixed = .boolean(true)
        return obj.jsValue
    }.jsValue

exports.makeTeleport =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let teleportID = args[3]

        let obj = makeEntityBase(id: id, type: "teleport", x: x, y: y, width: 4 * CELL_W, height: 1 * CELL_H)
        obj.teleportID = teleportID
        obj.fixed = .boolean(true)
        obj.timer = .number(0)
        return obj.jsValue
    }.jsValue

exports.makeJump =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let fixed = args[3]

        let obj = makeEntityBase(id: id, type: "jump", x: x, y: y, width: 2 * CELL_W, height: 1 * CELL_H)
        obj.animationFrame = .number(0)
        obj.fixed = fixed
        return obj.jsValue
    }.jsValue

exports.makeShield =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]
        let used = args[3]
        let fixed = args[4]

        let obj = makeEntityBase(id: id, type: "shield", x: x, y: y, width: 2 * CELL_W, height: 1 * CELL_H)
        obj.fixed = fixed
        obj.used = used
        return obj.jsValue
    }.jsValue

exports.makePipe =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]

        let obj = makeEntityBase(id: id, type: "pipe", x: x, y: y, width: 2 * CELL_W, height: 1 * CELL_H)
        obj.timer = .number(-1)
        obj.fixed = .boolean(true)
        return obj.jsValue
    }.jsValue

exports.makeDroplet =
    JSClosure { args in
        let id = args[0]
        let x = args[1]
        let y = args[2]

        let obj = makeEntityBase(id: id, type: "droplet", x: x, y: y, width: CELL_W, height: CELL_H)
        obj.splashing = .boolean(false)
        obj.animationFrame = .number(0)
        return obj.jsValue
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
