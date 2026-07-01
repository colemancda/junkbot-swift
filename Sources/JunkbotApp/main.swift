import JavaScriptKit
import JunkbotCore

nonisolated(unsafe) let window = JSObject.global
_ = window.console.log("Swift: module started")
let exports = JSObject.global.Object.function!.new()
let document = window.document.object!

func rectanglesIntersect(
    _ ax: Int32, _ ay: Int32, _ aw: Int32, _ ah: Int32,
    _ bx: Int32, _ by: Int32, _ bw: Int32, _ bh: Int32
) -> Bool {
    ax + aw > bx && ax < bx + bw && ay + ah > by && ay < by + bh
}

/// Reads `window.currentLevel.bounds` directly rather than mirroring it into a Swift-side global:
/// game.js declares `currentLevel` with `var` (not `let`) specifically so it's a real
/// `window.currentLevel` property this can read live, instead of JS having to push a copy into Swift
/// on every change.
func rectangleLevelBoundsCollision(x: Int32, y: Int32, width: Int32, height: Int32) -> (x: Int32, y: Int32, width: Int32, height: Int32)? {
    guard let currentLevel = window.currentLevel.object,
        let bounds = currentLevel.bounds.object,
        let bx = bounds.x.number, let by = bounds.y.number,
        let bw = bounds.width.number, let bh = bounds.height.number
    else { return nil }
    let boundsX = Int32(bx), boundsY = Int32(by), boundsW = Int32(bw), boundsH = Int32(bh)
    if x < boundsX {
        return (x: boundsX - CELL_W, y: boundsY, width: CELL_W, height: boundsH)
    }
    if y < boundsY {
        return (x: boundsX, y: boundsY - CELL_H, width: boundsW, height: CELL_H)
    }
    if x + width > boundsX + boundsW {
        return (x: boundsX + boundsW, y: boundsY, width: CELL_W, height: boundsH)
    }
    if y + height > boundsY + boundsH {
        return (x: boundsX, y: boundsY + boundsH, width: boundsW, height: CELL_H)
    }
    return nil
}

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

        let intersects = rectanglesIntersect(ax, ay, aw, ah, bx, by, bw, bh)

        return .boolean(intersects)
    }.jsValue

func rectangleLevelBoundsCollisionObject(x: Int32, y: Int32, width: Int32, height: Int32) -> JSValue? {
    guard let r = rectangleLevelBoundsCollision(x: x, y: y, width: width, height: height) else {
        return nil
    }
    let obj = JSObject.global.Object.function!.new()
    obj.type = "levelBounds".jsValue
    obj.x = r.x.jsValue
    obj.y = r.y.jsValue
    obj.width = r.width.jsValue
    obj.height = r.height.jsValue
    return obj.jsValue
}

/// Core collision scan taking a native Swift predicate, so Swift-side callers (e.g. a ported
/// simulate function) don't need to round-trip through a JS callable the way the JS-facing
/// `rectangleCollision`/`rectangleCollisionAll` below do.
func rectangleCollisionCore(
    x: Int32, y: Int32, width: Int32, height: Int32,
    entities: JSObject,
    filter: (JSObject) -> Bool
) -> JSValue? {
    if let bounds = rectangleLevelBoundsCollisionObject(x: x, y: y, width: width, height: height),
        let boundsObj = bounds.object, filter(boundsObj)
    {
        return bounds
    }
    let length = Int(entities.length.number ?? 0)
    for i in 0..<length {
        let other = entities[i]
        guard let otherObj = other.object else { continue }
        if otherObj.grabbed.boolean == true { continue }
        guard filter(otherObj) else { continue }
        let ox = Int32(otherObj.x.number ?? 0)
        let oy = Int32(otherObj.y.number ?? 0)
        let ow = Int32(otherObj.width.number ?? 0)
        let oh = Int32(otherObj.height.number ?? 0)
        if rectanglesIntersect(x, y, width, height, ox, oy, ow, oh) {
            return other
        }
    }
    return nil
}

func rectangleCollisionAllCore(
    x: Int32, y: Int32, width: Int32, height: Int32,
    entities: JSObject,
    filter: (JSObject) -> Bool
) -> [JSValue] {
    var result: [JSValue] = []
    if let bounds = rectangleLevelBoundsCollisionObject(x: x, y: y, width: width, height: height),
        let boundsObj = bounds.object, filter(boundsObj)
    {
        result.append(bounds)
    }
    let length = Int(entities.length.number ?? 0)
    for i in 0..<length {
        let other = entities[i]
        guard let otherObj = other.object else { continue }
        if otherObj.grabbed.boolean == true { continue }
        guard filter(otherObj) else { continue }
        let ox = Int32(otherObj.x.number ?? 0)
        let oy = Int32(otherObj.y.number ?? 0)
        let ow = Int32(otherObj.width.number ?? 0)
        let oh = Int32(otherObj.height.number ?? 0)
        if rectanglesIntersect(x, y, width, height, ox, oy, ow, oh) {
            result.append(other)
        }
    }
    return result
}

func rectangleCollision(
    x: Int32, y: Int32, width: Int32, height: Int32,
    filter: JSObject, entities: JSObject
) -> JSValue? {
    rectangleCollisionCore(x: x, y: y, width: width, height: height, entities: entities) { obj in
        filter(obj.jsValue).boolean == true
    }
}

func rectangleCollisionAll(
    x: Int32, y: Int32, width: Int32, height: Int32,
    filter: JSObject, entities: JSObject
) -> [JSValue] {
    rectangleCollisionAllCore(x: x, y: y, width: width, height: height, entities: entities) { obj in
        filter(obj.jsValue).boolean == true
    }
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

exports.winOrLose =
    JSClosure { args in
        guard let entities = args[0].object else { return .string("") }
        let length = Int(entities.length.number ?? 0)

        let junkbotType: JSString = "junkbot"
        let binType: JSString = "bin"

        var anyJunkbotAlive = false
        var anyJunkbotAliveNotDying = false
        var anyBin = false
        var allNotCollectingBin = true

        for i in 0..<length {
            guard let e = entities[i].object else { continue }
            let type = e.type.jsString
            if type == junkbotType {
                let dead = e.dead.boolean == true
                let dying = e.dying.boolean == true
                if !dead {
                    anyJunkbotAlive = true
                    if !dying { anyJunkbotAliveNotDying = true }
                }
            }
            if type == binType { anyBin = true }
            if e.collectingBin.boolean == true { allNotCollectingBin = false }
        }

        if !anyJunkbotAlive { return .string("lose") }
        if anyJunkbotAliveNotDying && !anyBin && allNotCollectingBin {
            return .string("win")
        }
        return .string("")
    }.jsValue

exports.rebuildAccelerationStructures =
    JSClosure { args in
        guard let entities = args[0].object else { return .undefined }
        let length = Int(entities.length.number ?? 0)

        var elements: [JSValue] = []
        var extents: [YExtent] = []
        elements.reserveCapacity(length)
        extents.reserveCapacity(length)
        for i in 0..<length {
            let element = entities[i]
            elements.append(element)
            let obj = element.object
            let y = Int32(obj?.y.number ?? 0)
            let height = Int32(obj?.height.number ?? 0)
            extents.append(YExtent(top: y, bottom: y + height))
        }

        let (byTop, byBottom) = groupIndicesByY(extents)

        func buildMap(_ grouping: [Int32: [Int]]) -> JSValue {
            let obj = JSObject.global.Object.function!.new()
            for (y, indices) in grouping {
                obj[Int(y)] = indices.map { elements[$0] }.jsValue
            }
            return obj.jsValue
        }

        let result = JSObject.global.Object.function!.new()
        result.byTopY = buildMap(byTop)
        result.byBottomY = buildMap(byBottom)
        return result.jsValue
    }.jsValue

func entitiesConnect(_ a: JSObject, _ b: JSObject, direction: Int32) -> Bool {
    let ax = Int32(a.x.number ?? 0), ay = Int32(a.y.number ?? 0)
    let aw = Int32(a.width.number ?? 0), ah = Int32(a.height.number ?? 0)
    let bx = Int32(b.x.number ?? 0), by = Int32(b.y.number ?? 0)
    let bw = Int32(b.width.number ?? 0), bh = Int32(b.height.number ?? 0)
    return ((direction >= 0 && by == ay + ah) || (direction <= 0 && by + bh == ay))
        && ax + aw > bx && ax < bx + bw
}

func yBucket(_ table: JSObject, _ y: Int32) -> [JSValue] {
    guard let arr = table[Int(y)].object else { return [] }
    let length = Int(arr.length.number ?? 0)
    return (0..<length).map { arr[$0] }
}

func jsObjectArray(_ value: JSValue) -> [JSObject] {
    guard let arr = value.object else { return [] }
    let length = Int(arr.length.number ?? 0)
    return (0..<length).compactMap { arr[$0].object }
}

exports.connects =
    JSClosure { args in
        guard let a = args[0].object, let b = args[1].object else { return .boolean(false) }
        let direction = Int32(args[2].number ?? 0)
        return .boolean(entitiesConnect(a, b, direction: direction))
    }.jsValue

func connectsToFixedCore(
    startEntity: JSObject, entitiesByTopY: JSObject, entitiesByBottomY: JSObject,
    direction: Int32, ignoreEntities: [JSObject]
) -> Bool {
    var visited: [JSObject] = []

    func search(_ fromEntity: JSObject) -> Bool {
        let fx = Int32(fromEntity.x.number ?? 0), fy = Int32(fromEntity.y.number ?? 0)
        let fw = Int32(fromEntity.width.number ?? 0), fh = Int32(fromEntity.height.number ?? 0)

        if let currentLevel = window.currentLevel.object, let bounds = currentLevel.bounds.object,
            let by = bounds.y.number, let bh = bounds.height.number,
            Double(fy + fh) >= by + bh
        {
            return true
        }

        let sameAsStart = fromEntity == startEntity
        let above = (!sameAsStart || direction != -1) ? yBucket(entitiesByTopY, fy + fh) : []
        let below = (!sameAsStart || direction != 1) ? yBucket(entitiesByBottomY, fy) : []

        for otherValue in above + below {
            guard let otherEntity = otherValue.object else { continue }
            if otherEntity.grabbed.boolean == true { continue }
            if ignoreEntities.contains(where: { $0 == otherEntity }) { continue }
            if visited.contains(where: { $0 == otherEntity }) { continue }
            let ox = Int32(otherEntity.x.number ?? 0), ow = Int32(otherEntity.width.number ?? 0)
            guard fx + fw > ox && fx < ox + ow else { continue }
            visited.append(otherEntity)
            if otherEntity.fixed.boolean == true { return true }
            if search(otherEntity) { return true }
        }
        return false
    }

    return search(startEntity)
}

exports.connectsToFixed =
    JSClosure { args in
        guard let startEntity = args[0].object,
            let entitiesByTopY = args[1].object,
            let entitiesByBottomY = args[2].object
        else { return .boolean(false) }
        let direction = Int32(args[3].number ?? 0)
        let ignoreEntities = jsObjectArray(args[4])

        return .boolean(
            connectsToFixedCore(
                startEntity: startEntity, entitiesByTopY: entitiesByTopY, entitiesByBottomY: entitiesByBottomY,
                direction: direction, ignoreEntities: ignoreEntities))
    }.jsValue

exports.allConnectedToFixed =
    JSClosure { args in
        guard let entities = args[0].object,
            let entitiesByTopY = args[1].object,
            let entitiesByBottomY = args[2].object
        else { return [JSValue]().jsValue }
        let ignoreEntities = jsObjectArray(args[3])

        var connectedToFixed: [JSObject] = []
        var connectedToFixedValues: [JSValue] = []

        func addAnyAttached(_ entity: JSObject) {
            let ex = Int32(entity.x.number ?? 0), ey = Int32(entity.y.number ?? 0)
            let ew = Int32(entity.width.number ?? 0), eh = Int32(entity.height.number ?? 0)
            let candidates = yBucket(entitiesByTopY, ey + eh) + yBucket(entitiesByBottomY, ey)
            for otherValue in candidates {
                guard let otherEntity = otherValue.object else { continue }
                let ox = Int32(otherEntity.x.number ?? 0), ow = Int32(otherEntity.width.number ?? 0)
                guard ex + ew > ox && ex < ox + ow else { continue }
                if ignoreEntities.contains(where: { $0 == otherEntity }) { continue }
                if connectedToFixed.contains(where: { $0 == otherEntity }) { continue }
                connectedToFixed.append(otherEntity)
                connectedToFixedValues.append(otherValue)
                addAnyAttached(otherEntity)
            }
        }

        let length = Int(entities.length.number ?? 0)
        for i in 0..<length {
            let entityValue = entities[i]
            guard let entity = entityValue.object else { continue }
            if ignoreEntities.contains(where: { $0 == entity }) { continue }
            if connectedToFixed.contains(where: { $0 == entity }) { continue }
            if entity.fixed.boolean == true {
                connectedToFixed.append(entity)
                connectedToFixedValues.append(entityValue)
                addAnyAttached(entity)
            }
        }

        return connectedToFixedValues.jsValue
    }.jsValue

exports.findMisplacedEntities =
    JSClosure { args in
        guard let within = args[0].object, let compareTo = args[1].object else { return [JSValue]().jsValue }

        let compareLength = Int(compareTo.length.number ?? 0)
        let compareEntities = (0..<compareLength).compactMap { compareTo[$0].object }

        let withinLength = Int(within.length.number ?? 0)
        var result: [JSValue] = []
        for i in 0..<withinLength {
            let entityValue = within[i]
            guard let entity = entityValue.object else { continue }
            let entityType = entity.type.jsString
            let entityGrabbed = entity.grabbed.boolean == true
            let ex = entity.x.number, ey = entity.y.number

            var misplaced = true
            for compareToEntity in compareEntities {
                guard entityType == compareToEntity.type.jsString else { continue }
                if entityGrabbed && compareToEntity.grabbed.boolean == true {
                    misplaced = false
                    break
                }
                if ex == compareToEntity.x.number && ey == compareToEntity.y.number {
                    misplaced = false
                    break
                }
            }
            if misplaced { result.append(entityValue) }
        }
        return result.jsValue
    }.jsValue

exports.simulateGravity =
    JSClosure { args in
        guard let entities = args[0].object,
            let entitiesByTopY = args[1].object,
            let entitiesByBottomY = args[2].object,
            let entityMoved = args[3].function
        else { return .undefined }

        let dropletType: JSString = "droplet"
        let junkbotType: JSString = "junkbot"
        let climbbotType: JSString = "climbbot"
        let flybotType: JSString = "flybot"
        let eyebotType: JSString = "eyebot"
        let gearbotType: JSString = "gearbot"
        let crateType: JSString = "crate"
        let binType: JSString = "bin"

        func isNotDroplet(_ e: JSObject) -> Bool {
            e.type.jsString != dropletType
        }

        let length = Int(entities.length.number ?? 0)
        for i in 0..<length {
            let entityValue = entities[i]
            guard let entity = entityValue.object else { continue }
            if entity.fixed.boolean == true { continue }
            if entity.grabbed.boolean == true { continue }
            if entity.floating.boolean == true { continue }
            let type = entity.type.jsString
            if type == dropletType || type == junkbotType || type == climbbotType || type == flybotType
                || type == eyebotType
            {
                continue
            }

            let ex = Int32(entity.x.number ?? 0)
            let ey = Int32(entity.y.number ?? 0)
            let ew = Int32(entity.width.number ?? 0)
            let eh = Int32(entity.height.number ?? 0)

            // "settled" checks: touching the level floor, or resting on something connected to fixed
            if rectangleLevelBoundsCollisionObject(x: ex, y: ey + 1, width: ew, height: eh) != nil {
                continue
            }
            let direction: Int32 =
                (type == junkbotType || type == gearbotType || type == crateType || type == binType) ? 1 : 0
            if connectsToFixedCore(
                startEntity: entity, entitiesByTopY: entitiesByTopY, entitiesByBottomY: entitiesByBottomY,
                direction: direction, ignoreEntities: [])
            {
                continue
            }

            // (debug-overlay-only logging from the original is omitted here; it has no gameplay effect)
            if rectangleCollisionCore(
                x: ex, y: ey, width: ew, height: eh, entities: entities,
                filter: { other in other != entity && isNotDroplet(other) }) != nil
            {
                // Faithful port of the original: this returns out of the whole function (not just
                // `continue`s to the next entity) when an entity is stuck in the ground.
                return .undefined
            }

            let cellDownY = ey + CELL_H
            let hits = rectangleCollisionAllCore(
                x: ex, y: cellDownY + 1, width: ew, height: eh, entities: entities,
                filter: { other in other != entity && isNotDroplet(other) })
            let ground = hits.compactMap { $0.object }.min(by: { ($0.y.number ?? 0) < ($1.y.number ?? 0) })

            if let ground = ground, let groundY = ground.y.number {
                entity.y = (Int32(groundY) - eh).jsValue
            } else {
                entity.y = cellDownY.jsValue
            }
            _ = entityMoved(entityValue)
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
