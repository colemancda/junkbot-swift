import JavaScriptKit
import JunkbotCore

nonisolated(unsafe) let window = JSObject.global
_ = window.console.log("Swift: module started")
let exports = JSObject.global.Object.function!.new()
let document = window.document.object!

let dropletType: JSString = "droplet"
let binType: JSString = "bin"
let junkbotType: JSString = "junkbot"
let gearbotType: JSString = "gearbot"
let climbbotType: JSString = "climbbot"
let flybotType: JSString = "flybot"
let eyebotType: JSString = "eyebot"
let crateType: JSString = "crate"
let teleportType: JSString = "teleport"

let TELEPORT_COOLDOWN: Int32 = 50
let TELEPORT_EFFECT_PERIOD: Int32 = 20

func entityType(_ e: JSObject) -> JSString? { e.type.jsString }
func isNotDroplet(_ e: JSObject) -> Bool { entityType(e) != dropletType }
func isNotBinOrDroplet(_ e: JSObject) -> Bool { entityType(e) != binType && isNotDroplet(e) }
func isNotBinOrDropletOrEnemyBot(_ e: JSObject) -> Bool {
    isNotBinOrDroplet(e) && entityType(e) != gearbotType && entityType(e) != climbbotType
        && entityType(e) != flybotType && entityType(e) != eyebotType
}
func isNotDropletOrJunkbot(_ e: JSObject) -> Bool { isNotDroplet(e) && entityType(e) != junkbotType }

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

/// Swift-native analog of the JS `entityCollisionTest` helper: same as `rectangleCollisionCore`, but
/// using `entity`'s own width/height and excluding `entity` itself from candidates (note: use a
/// candidate x/y, not `entity`'s own x/y, matching the original's "make sure not to use entity.x/y!").
func entityCollision(
    x: Int32, y: Int32, entity: JSObject, entities: JSObject, filter: (JSObject) -> Bool
) -> JSValue? {
    let width = Int32(entity.width.number ?? 0)
    let height = Int32(entity.height.number ?? 0)
    return rectangleCollisionCore(x: x, y: y, width: width, height: height, entities: entities) { other in
        other != entity && filter(other)
    }
}

func entityCollisionAllSwift(
    x: Int32, y: Int32, entity: JSObject, entities: JSObject, filter: (JSObject) -> Bool
) -> [JSValue] {
    let width = Int32(entity.width.number ?? 0)
    let height = Int32(entity.height.number ?? 0)
    return rectangleCollisionAllCore(x: x, y: y, width: width, height: height, entities: entities) { other in
        other != entity && filter(other)
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

        let length = Int(entities.length.number ?? 0)
        for i in 0..<length {
            let entityValue = entities[i]
            guard let entity = entityValue.object else { continue }
            if entity.fixed.boolean == true { continue }
            if entity.grabbed.boolean == true { continue }
            if entity.floating.boolean == true { continue }
            let type = entityType(entity)
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

let fireCause: JSString = "fire"
let waterCause: JSString = "water"
let laserCause: JSString = "laser"

func hurtJunkbotCore(junkbot: JSObject, cause: JSString?, playSound: JSObject) {
    if junkbot.dying.boolean == true || junkbot.dead.boolean == true || junkbot.grabbed.boolean == true {
        return
    }

    // Play sound even if shielded, but not if losing shield because then it would repeat and
    // sound ugly. This has to be before junkbot.losingShield is set, so it can play the first time.
    if junkbot.losingShield.boolean != true {
        if cause == fireCause {
            _ = playSound("deathByFire")
        } else if cause == waterCause {
            _ = playSound("deathByWater")
        } else if cause == laserCause {
            _ = playSound("deathByLaser")
        } else {
            _ = playSound("deathByBot")
        }
    }

    if junkbot.armored.boolean == true {
        if junkbot.losingShield.boolean != true {
            junkbot.losingShield = .boolean(true)
            // don't reset junkbot.losingShieldTime to 0 - it wouldn't make sense for multiple
            // hits to extend the shield (it should be reset elsewhere)
        }
    } else {
        junkbot.animationFrame = .number(0)
        junkbot.collectingBin = .boolean(false)
        junkbot.dying = .boolean(true)
        if cause == waterCause {
            junkbot.dyingFromWater = .boolean(true)
        }
    }
}

exports.hurtJunkbot =
    JSClosure { args in
        guard let junkbot = args[0].object, let playSound = args[2].function else { return .undefined }
        hurtJunkbotCore(junkbot: junkbot, cause: args[1].jsString, playSound: playSound)
        return .undefined
    }.jsValue

exports.walk =
    JSClosure { args in
        guard let junkbot = args[0].object, let entities = args[1].object, let entityMoved = args[2].function,
            let playSound = args[3].function
        else { return .undefined }

        let jx = Int32(junkbot.x.number ?? 0)
        let jy = Int32(junkbot.y.number ?? 0)
        let jh = Int32(junkbot.height.number ?? 0)
        let facing = Int32(junkbot.facing.number ?? 0)

        let frontX = jx + facing * CELL_W
        let frontY = jy

        // can we step up?
        if let stepOrWall = entityCollision(
            x: frontX, y: frontY, entity: junkbot, entities: entities, filter: isNotBinOrDropletOrEnemyBot
        )?.object, let wallY = stepOrWall.y.number {
            let stepUpY = Int32(wallY) - jh
            if stepUpY - jy >= -CELL_H && stepUpY - jy < 0
                && entityCollision(
                    x: frontX, y: stepUpY, entity: junkbot, entities: entities, filter: isNotBinOrDroplet) == nil
            {
                junkbot.x = frontX.jsValue
                junkbot.y = stepUpY.jsValue
                _ = entityMoved(args[0])
                return .undefined
            }
        }

        // is there solid ground ahead to walk on?
        let ground = entityCollision(
            x: frontX, y: frontY + 1, entity: junkbot, entities: entities, filter: isNotBinOrDropletOrEnemyBot)
        if ground != nil,
            entityCollision(x: frontX, y: frontY, entity: junkbot, entities: entities, filter: isNotBinOrDroplet)
                == nil
        {
            junkbot.x = frontX.jsValue
            junkbot.y = frontY.jsValue
            _ = entityMoved(args[0])
            return .undefined
        }

        // can we step down?
        let stepsBelow = entityCollisionAllSwift(
            x: frontX, y: frontY + CELL_H + 1, entity: junkbot, entities: entities,
            filter: isNotBinOrDropletOrEnemyBot)
        if let step = stepsBelow.compactMap({ $0.object }).min(by: { ($0.y.number ?? 0) < ($1.y.number ?? 0) }),
            let stepY = step.y.number
        {
            let stepDownY = Int32(stepY) - jh
            let stepDownHits = entityCollisionAllSwift(
                x: frontX, y: stepDownY + 1, entity: junkbot, entities: entities,
                filter: isNotBinOrDropletOrEnemyBot)
            let stepDown = stepDownHits.compactMap { $0.object }.min(by: {
                ($0.y.number ?? 0) < ($1.y.number ?? 0)
            })
            if stepDownY - jy <= CELL_H && stepDownY - jy > 0 && stepDown != nil
                && entityCollision(
                    x: frontX, y: stepDownY, entity: junkbot, entities: entities, filter: isNotBinOrDroplet) == nil
            {
                junkbot.x = frontX.jsValue
                junkbot.y = stepDownY.jsValue
                _ = entityMoved(args[0])
                return .undefined
            }
        }

        junkbot.facing = (-facing).jsValue
        _ = playSound("turn")
        return .string("turned")
    }.jsValue

exports.simulateJump =
    JSClosure { args in
        guard let jump = args[0].object else { return .undefined }
        let animationFrame = Int32(jump.animationFrame.number ?? 0) + 1
        if animationFrame >= 5 {
            jump.animationFrame = .number(0)
            jump.active = .boolean(false)
        } else {
            jump.animationFrame = animationFrame.jsValue
        }
        return .undefined
    }.jsValue

exports.simulateGearbot =
    JSClosure { args in
        guard let gearbot = args[0].object, let entities = args[1].object,
            let entityMoved = args[2].function, let playSound = args[3].function
        else { return .undefined }

        let animationFrame = Int32(gearbot.animationFrame.number ?? 0) + 1
        guard animationFrame > 2 else {
            gearbot.animationFrame = animationFrame.jsValue
            return .undefined
        }
        gearbot.animationFrame = .number(0)

        let gx = Int32(gearbot.x.number ?? 0)
        let gy = Int32(gearbot.y.number ?? 0)
        let gw = Int32(gearbot.width.number ?? 0)
        let gh = Int32(gearbot.height.number ?? 0)
        let facing = Int32(gearbot.facing.number ?? 0)

        let aheadX = gx + facing * CELL_W
        let aheadY = gy
        let ahead = entityCollision(
            x: aheadX, y: aheadY, entity: gearbot, entities: entities, filter: isNotDroplet
        )?.object

        let groundAheadX = facing == -1 ? gx - CELL_W : gx + gw
        let groundAhead = rectangleCollisionCore(
            x: groundAheadX, y: gy + 1, width: CELL_W, height: gh, entities: entities, filter: isNotDroplet)

        if let ahead = ahead {
            if entityType(ahead) == junkbotType, ahead.dying.boolean != true, ahead.dead.boolean != true {
                hurtJunkbotCore(junkbot: ahead, cause: "bot", playSound: playSound)
            }
            gearbot.facing = (-facing).jsValue
        } else if groundAhead != nil {
            gearbot.x = aheadX.jsValue
            gearbot.y = aheadY.jsValue
            _ = entityMoved(args[0])
        } else {
            gearbot.facing = (-facing).jsValue
        }
        return .undefined
    }.jsValue

exports.simulateFlybot =
    JSClosure { args in
        guard let flybot = args[0].object, let entities = args[1].object,
            let entityMoved = args[2].function, let playSound = args[3].function
        else { return .undefined }

        let animationFrame = Int32(flybot.animationFrame.number ?? 0) + 1
        flybot.animationFrame = animationFrame.jsValue
        guard animationFrame % 2 == 0 else { return .undefined }

        let fx = Int32(flybot.x.number ?? 0)
        let fy = Int32(flybot.y.number ?? 0)
        let facing = Int32(flybot.facing.number ?? 0)
        let aheadX = fx + facing * CELL_W
        let aheadY = fy

        if let ahead = entityCollision(
            x: aheadX, y: aheadY, entity: flybot, entities: entities, filter: isNotDroplet
        )?.object {
            if entityType(ahead) == junkbotType {
                hurtJunkbotCore(junkbot: ahead, cause: "bot", playSound: playSound)
            }
            flybot.facing = (-facing).jsValue
        } else {
            flybot.x = aheadX.jsValue
            flybot.y = aheadY.jsValue
            _ = entityMoved(args[0])
        }
        return .undefined
    }.jsValue

exports.simulateScaredy =
    JSClosure { args in
        guard let bin = args[0].object, let entities = args[1].object, let entityMoved = args[2].function
        else { return .undefined }

        let animationFrame = Int32(bin.animationFrame.number ?? 0) + 1
        guard animationFrame > 2 else {
            bin.animationFrame = animationFrame.jsValue
            return .undefined
        }
        bin.animationFrame = .number(0)

        let bx = Int32(bin.x.number ?? 0)
        let by = Int32(bin.y.number ?? 0)
        let bw = Int32(bin.width.number ?? 0)
        let bh = Int32(bin.height.number ?? 0)
        let searchDist: Int32 = CELL_W * 4  // AKA scare distance

        // (debug-overlay-only visualization from the original is omitted here; no gameplay effect)
        let junkbot = rectangleCollisionCore(
            x: bx - searchDist, y: by, width: bw + searchDist * 2, height: bh, entities: entities,
            filter: { entityType($0) == junkbotType }
        )?.object

        if let junkbot = junkbot {
            let jx = Int32(junkbot.x.number ?? 0)
            let facing: Int32 = jx > bx ? -1 : 1
            bin.facing = facing.jsValue
            let aheadX = bx + facing * CELL_W
            let aheadY = by
            if entityCollision(x: aheadX, y: aheadY, entity: bin, entities: entities, filter: isNotDroplet) != nil {
                bin.facing = .number(0)
            } else {
                bin.x = aheadX.jsValue
                bin.y = aheadY.jsValue
                _ = entityMoved(args[0])
            }
        } else {
            bin.facing = .number(0)
        }
        return .undefined
    }.jsValue

exports.simulateDroplet =
    JSClosure { args in
        guard let droplet = args[0].object, let entitiesByTopY = args[1].object,
            let entityMoved = args[2].function, let playSound = args[3].function
        else { return .undefined }

        if droplet.splashing.boolean == true {
            let animationFrame = Int32(droplet.animationFrame.number ?? 0) + 1
            droplet.animationFrame = animationFrame.jsValue
            if animationFrame > 4 {
                droplet.removeBeforeRender = .boolean(true)  // important not to remove while iterating
            }
            return .undefined
        }

        // Cosmetic sound choice only (doesn't affect gameplay), fixed 3-way set matching `numDrips`;
        // uses Swift's own RNG rather than round-tripping to JS's Math.random().
        let dripSounds: [JSValue] = ["drip0".jsValue, "drip1".jsValue, "drip2".jsValue]
        let dx = Int32(droplet.x.number ?? 0)
        let dw = Int32(droplet.width.number ?? 0)

        for _ in 0..<18 {
            let dy = Int32(droplet.y.number ?? 0)
            let dh = Int32(droplet.height.number ?? 0)
            let underneath = yBucket(entitiesByTopY, dy + dh)
            droplet.y = (dy + 1).jsValue
            _ = entityMoved(args[0])

            for groundValue in underneath {
                guard let ground = groundValue.object else { continue }
                if ground.grabbed.boolean == true { continue }
                let gx = Int32(ground.x.number ?? 0)
                let gw = Int32(ground.width.number ?? 0)
                guard dx + dw > gx && dx < gx + gw else { continue }
                guard entityType(ground) != dropletType else { continue }

                if entityType(ground) == junkbotType {
                    hurtJunkbotCore(junkbot: ground, cause: "water", playSound: playSound)
                }

                droplet.splashing = .boolean(true)
                droplet.animationFrame = .number(0)
                _ = playSound(dripSounds[Int.random(in: 0..<3)])
                break
            }
        }
        return .undefined
    }.jsValue

let maxDripPeriod: Int32 = 50
let minDripPeriod: Int32 = 20

exports.simulatePipe =
    JSClosure { args in
        guard let pipe = args[0].object, let entities = args[1].object, let getID = args[2].function
        else { return .undefined }

        let timer = Int32(pipe.timer.number ?? 0) - 1
        pipe.timer = timer.jsValue

        // @TODO (kept from the original): how do pipe drips actually work in the original game?
        if timer == 0 {
            let droplet = makeEntityBase(
                id: getID(), type: "droplet", x: pipe.x, y: pipe.y, width: CELL_W, height: CELL_H)
            droplet.splashing = .boolean(false)
            droplet.animationFrame = .number(0)
            _ = entities.push!(droplet.jsValue)
        }
        if timer <= 0 {  // includes initial -1 for initial randomization
            let period = Int32.random(in: 0..<(maxDripPeriod - minDripPeriod)) + minDripPeriod
            pipe.timer = period.jsValue
        }
        return .undefined
    }.jsValue

func findLinkedTeleportCore(teleport: JSObject, entities: JSObject) -> JSObject? {
    let teleportID = teleport.teleportID.number
    let length = Int(entities.length.number ?? 0)
    for i in 0..<length {
        guard let other = entities[i].object else { continue }
        guard entityType(other) == teleportType else { continue }
        guard other.teleportID.number == teleportID else { continue }
        guard other != teleport else { continue }
        return other
    }
    return nil
}

exports.findLinkedTeleport =
    JSClosure { args in
        guard let teleport = args[0].object, let entities = args[1].object else { return .undefined }
        return findLinkedTeleportCore(teleport: teleport, entities: entities)?.jsValue ?? .undefined
    }.jsValue

exports.simulateTeleport =
    JSClosure { args in
        guard let teleport = args[0].object, let entities = args[1].object, let teleportEffects = args[2].object
        else { return .undefined }

        var timer = Int32(teleport.timer.number ?? 0)
        if timer > 0 {
            timer -= 1
            teleport.timer = timer.jsValue
        }

        let target = findLinkedTeleportCore(teleport: teleport, entities: entities)
        let tx = Int32(teleport.x.number ?? 0)
        let ty = Int32(teleport.y.number ?? 0)

        var blocked = true
        if let target = target {
            let selfBlocked =
                rectangleCollisionCore(
                    x: tx + CELL_W, y: ty - CELL_H * 4, width: CELL_W * 2, height: CELL_H * 4, entities: entities,
                    filter: isNotDropletOrJunkbot) != nil
            if selfBlocked {
                blocked = true
            } else {
                let tgx = Int32(target.x.number ?? 0)
                let tgy = Int32(target.y.number ?? 0)
                blocked =
                    rectangleCollisionCore(
                        x: tgx + CELL_W, y: tgy - CELL_H * 4, width: CELL_W * 2, height: CELL_H * 4,
                        entities: entities, filter: isNotDropletOrJunkbot) != nil
            }
        }
        teleport.blocked = .boolean(blocked)

        if timer > TELEPORT_COOLDOWN - TELEPORT_EFFECT_PERIOD {
            let effect = JSObject.global.Object.function!.new()
            effect.x = (tx + CELL_W).jsValue
            effect.y = ty.jsValue
            effect.frameIndex = (timer % 3).jsValue
            _ = teleportEffects.push!(effect.jsValue)
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
