import JavaScriptKit
import JunkbotCore

nonisolated(unsafe) let window = JSObject.global
_ = window.console.log("Swift: module started")
let exports = JSObject.global.Object.function!.new()
let document = window.document.object!
let gameEngine = GameEngine()

extension GameEngine {
    func rectanglesIntersectExport(_ args: [JSValue]) -> JSValue {
        let ax = Int32(args[0].number ?? 0)
        let ay = Int32(args[1].number ?? 0)
        let aw = Int32(args[2].number ?? 0)
        let ah = Int32(args[3].number ?? 0)

        let bx = Int32(args[4].number ?? 0)
        let by = Int32(args[5].number ?? 0)
        let bw = Int32(args[6].number ?? 0)
        let bh = Int32(args[7].number ?? 0)

        return .boolean(rectanglesIntersect(ax, ay, aw, ah, bx, by, bw, bh))
    }

    func rectangleLevelBoundsCollisionTestExport(_ args: [JSValue]) -> JSValue {
        let x = Int32(args[0].number ?? 0)
        let y = Int32(args[1].number ?? 0)
        let width = Int32(args[2].number ?? 0)
        let height = Int32(args[3].number ?? 0)
        return rectangleLevelBoundsCollisionObject(x: x, y: y, width: width, height: height) ?? .undefined
    }

    func rectangleCollisionTestExport(_ args: [JSValue]) -> JSValue {
        let x = Int32(args[0].number ?? 0)
        let y = Int32(args[1].number ?? 0)
        let width = Int32(args[2].number ?? 0)
        let height = Int32(args[3].number ?? 0)
        guard let filter = args[4].function, let entities = args[5].object else { return .null }

        return rectangleCollision(x: x, y: y, width: width, height: height, filter: filter, entities: entities)
            ?? .null
    }

    func rectangleCollisionAllExport(_ args: [JSValue]) -> JSValue {
        let x = Int32(args[0].number ?? 0)
        let y = Int32(args[1].number ?? 0)
        let width = Int32(args[2].number ?? 0)
        let height = Int32(args[3].number ?? 0)
        guard let filter = args[4].function, let entities = args[5].object else { return [JSValue]().jsValue }

        return rectangleCollisionAll(x: x, y: y, width: width, height: height, filter: filter, entities: entities)
            .jsValue
    }

    func raycastExport(_ args: [JSValue]) -> JSValue {
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
    }

    func worldToCanvasExport(_ args: [JSValue]) -> JSValue {
        let point = worldToCanvas(
            worldX: args[0].number ?? 0, worldY: args[1].number ?? 0,
            centerX: args[2].number ?? 0, centerY: args[3].number ?? 0, scale: args[4].number ?? 1,
            canvasWidth: args[5].number ?? 0, canvasHeight: args[6].number ?? 0
        )
        let result = JSObject.global.Object.function!.new()
        result.x = point.x.jsValue
        result.y = point.y.jsValue
        return result.jsValue
    }

    func canvasToWorldExport(_ args: [JSValue]) -> JSValue {
        let point = canvasToWorld(
            canvasX: args[0].number ?? 0, canvasY: args[1].number ?? 0,
            centerX: args[2].number ?? 0, centerY: args[3].number ?? 0, scale: args[4].number ?? 1,
            canvasWidth: args[5].number ?? 0, canvasHeight: args[6].number ?? 0
        )
        let result = JSObject.global.Object.function!.new()
        result.x = point.x.jsValue
        result.y = point.y.jsValue
        return result.jsValue
    }

    func sortEntitiesForRenderingExport(_ args: [JSValue]) -> JSValue {
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
    }

    func winOrLoseExport(_ args: [JSValue]) -> JSValue {
        guard let entities = args[0].object else { return .string("") }
        let length = Int(entities.length.number ?? 0)

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
    }

    func rebuildAccelerationStructuresExport(_ args: [JSValue]) -> JSValue {
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
    }

    func connectsExport(_ args: [JSValue]) -> JSValue {
        guard let a = args[0].object, let b = args[1].object else { return .boolean(false) }
        let direction = Int32(args[2].number ?? 0)
        return .boolean(entitiesConnect(a, b, direction: direction))
    }

    func connectsToFixedExport(_ args: [JSValue]) -> JSValue {
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
    }

    func allConnectedToFixedExport(_ args: [JSValue]) -> JSValue {
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
    }

    func makeEntityExport(_ kind: JSString, _ args: [JSValue]) -> JSValue {
        let id = args[0]
        let x = args[1]
        let y = args[2]

        if kind == "brick" {
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
        }
        if kind == junkbotType {
            let obj = makeEntityBase(id: id, type: "junkbot", x: x, y: y, width: 2 * CELL_W, height: 4 * CELL_H)
            obj.facing = args[3]
            obj.armored = args[4]
            obj.losingShield = .boolean(false)
            obj.losingShieldTime = .number(0)
            obj.animationFrame = .number(0)
            obj.headLoaded = .boolean(false)
            return obj.jsValue
        }
        if kind == gearbotType {
            let obj = makeEntityBase(id: id, type: "gearbot", x: x, y: y, width: 2 * CELL_W, height: 2 * CELL_H)
            obj.facing = args[3]
            obj.animationFrame = .number(0)
            return obj.jsValue
        }
        if kind == climbbotType {
            let obj = makeEntityBase(id: id, type: "climbbot", x: x, y: y, width: 2 * CELL_W, height: 2 * CELL_H)
            obj.facing = args[3]
            obj.facingY = args[4]
            obj.animationFrame = .number(0)
            obj.energy = .number(0)
            return obj.jsValue
        }
        if kind == flybotType {
            let obj = makeEntityBase(id: id, type: "flybot", x: x, y: y, width: 2 * CELL_W, height: 2 * CELL_H)
            obj.facing = args[3]
            obj.animationFrame = .number(0)
            return obj.jsValue
        }
        if kind == eyebotType {
            let obj = makeEntityBase(id: id, type: "eyebot", x: x, y: y, width: 2 * CELL_W, height: 2 * CELL_H)
            obj.facing = args[3]
            obj.facingY = args[4]
            obj.animationFrame = .number(0)
            return obj.jsValue
        }
        if kind == binType {
            let obj = makeEntityBase(id: id, type: "bin", x: x, y: y, width: 2 * CELL_W, height: 3 * CELL_H)
            obj.facing = args[3]
            obj.scaredy = args[4]
            obj.animationFrame = .number(0)
            return obj.jsValue
        }
        if kind == crateType {
            return makeEntityBase(id: id, type: "crate", x: x, y: y, width: 3 * CELL_W, height: 2 * CELL_H).jsValue
        }
        if kind == fireType {
            let obj = makeEntityBase(id: id, type: "fire", x: x, y: y, width: 4 * CELL_W, height: CELL_H)
            obj.on = args[3]
            obj.switchID = args[4]
            obj.animationFrame = .number(0)
            obj.fixed = .boolean(true)
            return obj.jsValue
        }
        if kind == fanType {
            let obj = makeEntityBase(id: id, type: "fan", x: x, y: y, width: 4 * CELL_W, height: CELL_H)
            obj.on = args[3]
            obj.switchID = args[4]
            obj.animationFrame = .number(0)
            obj.fixed = .boolean(true)
            return obj.jsValue
        }
        if kind == laserType {
            let obj = makeEntityBase(id: id, type: "laser", x: x, y: y, width: 2 * CELL_W, height: CELL_H)
            obj.on = args[3]
            obj.switchID = args[4]
            obj.animationFrame = .number(0)
            obj.facing = args[5]
            obj.fixed = .boolean(true)
            return obj.jsValue
        }
        if kind == switchType {
            let obj = makeEntityBase(id: id, type: "switch", x: x, y: y, width: 2 * CELL_W, height: CELL_H)
            obj.on = args[3]
            obj.switchID = args[4]
            obj.fixed = .boolean(true)
            return obj.jsValue
        }
        if kind == teleportType {
            let obj = makeEntityBase(id: id, type: "teleport", x: x, y: y, width: 4 * CELL_W, height: CELL_H)
            obj.teleportID = args[3]
            obj.fixed = .boolean(true)
            obj.timer = .number(0)
            return obj.jsValue
        }
        if kind == jumpType {
            let obj = makeEntityBase(id: id, type: "jump", x: x, y: y, width: 2 * CELL_W, height: CELL_H)
            obj.animationFrame = .number(0)
            obj.fixed = args[3]
            return obj.jsValue
        }
        if kind == shieldType {
            let obj = makeEntityBase(id: id, type: "shield", x: x, y: y, width: 2 * CELL_W, height: CELL_H)
            obj.fixed = args[4]
            obj.used = args[3]
            return obj.jsValue
        }
        if kind == "pipe" {
            let obj = makeEntityBase(id: id, type: "pipe", x: x, y: y, width: 2 * CELL_W, height: CELL_H)
            obj.timer = .number(-1)
            obj.fixed = .boolean(true)
            return obj.jsValue
        }
        if kind == dropletType {
            let obj = makeEntityBase(id: id, type: "droplet", x: x, y: y, width: CELL_W, height: CELL_H)
            obj.splashing = .boolean(false)
            obj.animationFrame = .number(0)
            return obj.jsValue
        }
        return .undefined
    }

    func findMisplacedEntitiesExport(_ args: [JSValue]) -> JSValue {
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
    }

    func engineLoadLevelExport(_ args: [JSValue]) -> JSValue {
        guard let level = args[0].object else { return .undefined }

        let nextID = Int32(args[1].number ?? 0)
        let state = engineLevelState(from: level)
        loadLevelState(entities: state.entities, levelBounds: state.bounds, nextID: nextID)
        return .undefined
    }

    /// Merges just the currently-`grabbed` (mid-drag) entities' position/offset from the JS
    /// mirror into this engine's persistent `entities`, instead of replacing all of `entities`
    /// from JS every tick (contrast the old `engineTickExport` behavior, still used by
    /// `engineLoadLevelExport`'s one-time load path via `loadLevelState`). This is the one place
    /// JS still feeds live state into Swift each frame: dragging (`updateDrag` in src/game.js)
    /// mutates the JS-side entity's x/y directly every frame, and Swift needs to see that
    /// update before its own physics runs that tick. Everything else in `entities` is
    /// Swift-owned and persists across ticks untouched.
    ///
    /// Also adopts brand-new entities introduced while already `grabbed` (e.g. paste-while-
    /// dragging in the editor — pasted entities start `grabbed = true`), and drops any
    /// Swift-side entity whose JS counterpart no longer exists (e.g. deleted mid-drag), so
    /// neither case leaves a stale/ghost entity behind. Editor actions that don't involve an
    /// in-progress grab (plain delete, flip/rotate, the palette hover-preview) are NOT covered
    /// by this merge — a known, tracked gap (see project plan), not a regression from today's
    /// full-replace behavior, since those are comparatively rare/editor-only paths.
    func mergeGrabbedEntities(from jsEntities: JSObject) {
        let length = Int(jsEntities.length.number ?? 0)
        var jsById: [Int32: JSObject] = [:]
        for i in 0..<length {
            guard let obj = jsEntities[i].object else { continue }
            jsById[Int32(obj.id.number ?? -1)] = obj
        }

        // Entities Swift's own native play-mode drag (`draggingIndices`, driven by `mouseDown`/
        // `mouseMove`/`mouseUp` — see Input.swift) is already tracking are authoritative from
        // Swift's side. JS's mirror of `grabbed` for these lags one tick behind (it's only
        // refreshed by this tick's own `syncEngineEntities`, after this function runs), so merging
        // it in here would immediately clobber a just-started native drag back to `grabbed: false`
        // on its very first tick. Skip them; this merge is for JS-initiated (editor-mode) drags.
        let nativelyDraggingIDs = draggingEntityIDs

        for (id, obj) in jsById {
            guard !nativelyDraggingIDs.contains(id) else { continue }
            let jsGrabbed = obj.grabbed.boolean == true
            if let idx = entities.firstIndex(where: { $0.id == id }) {
                guard jsGrabbed || entities[idx].grabbed else { continue }
                entities[idx].grabbed = jsGrabbed
                entities[idx].x = Int32(obj.x.number ?? 0)
                entities[idx].y = Int32(obj.y.number ?? 0)
                if let offset = obj.grabOffset.object {
                    entities[idx].grabOffsetX = Int32(offset.x.number ?? 0)
                    entities[idx].grabOffsetY = Int32(offset.y.number ?? 0)
                }
            } else if jsGrabbed {
                entities.append(engineEntity(from: obj))
            }
        }

        entities.removeAll { $0.grabbed && jsById[$0.id] == nil }
    }

    func engineTickExport(_ args: [JSValue]) -> JSValue {
        guard let entities = args[0].object, let wind = args[1].object, let laserBeams = args[2].object,
            let teleportEffects = args[3].object, let playSound = args[6].function
        else { return .undefined }
        let nextID = Int32(args[5].number ?? 0)
        // frameCounter is now Swift-owned (incremented inside tick()/simulate()); no longer
        // overwritten from JS's args[7] here. The result object below still reports it back so
        // JS's own `frameCounter` (used for playthrough/rewind timestamping) stays in sync.

        var collectedBin = false
        onPlaySound = { id in
            if id == 6 { collectedBin = true }
            guard let soundName = engineSoundName(id) else { return }
            _ = playSound(soundName)
        }

        // Records a native play-mode drag's pickup/place into JS's `playthroughEvents` (solution
        // recording/replay), mirroring what JS's own `startGrab`/`finishDrag` used to push before
        // play-mode dragging moved to Swift. `recordDragEvent` persists across ticks the same way
        // `onPlaySound` does — it's set here but invoked later, from `mouseDown`/`mouseMove`/
        // `mouseUp`, which run outside of any `engineTick` call.
        if let recordDragEvent = args[9].function {
            onDragEvent = { isPickup, worldX, worldY, direction in
                let grabType: JSString = direction == -1 ? "upward" : (direction == 1 ? "downward" : "single")
                _ = recordDragEvent(isPickup, worldX, worldY, grabType)
            }
        }

        // Only merge JS's `grabbed` mirror into Swift while editing: editor-mode dragging still
        // sets `entity.grabbed` directly on JS objects (this is how Swift learns about it), but
        // play-mode dragging is entirely Swift-native now (mouseDown/mouseMove/mouseUp) - JS never
        // independently sets `grabbed` there anymore. Merging unconditionally would clobber a
        // just-finished native release: JS's mirror is always one tick stale, so right after
        // `mouseUp` clears `draggingIndices`, this merge would still see the old `grabbed: true`
        // and re-grab the entity in Swift before this tick's sync corrects the mirror.
        if args[8].boolean == true {
            mergeGrabbedEntities(from: entities)
        }
        ensureIDCounterAtLeast(nextID)
        tick()
        syncEngineEntities(to: entities)
        syncEngineEffects(entities: entities, wind: wind, laserBeams: laserBeams, teleportEffects: teleportEffects)

        let result = JSObject.global.Object.function!.new()
        result.frameCounter = frameCounter.jsValue
        result.collectedBin = collectedBin.jsValue
        // `moves` is also Swift-owned now (incremented by Input.swift's startDrag for play-mode
        // grabs, which JS no longer sees directly since it no longer calls its own startGrab for
        // those). Editor-mode grabs never increment it (matches JS's original `if (!editing)`
        // guard in startGrab), so reporting it back unconditionally is a no-op during editing.
        result.moves = moves.jsValue
        return result.jsValue
    }

    // hurtJunkbotExport, walkExport, simulateJumpExport, findLinkedTeleportExport removed: dead code,
    // never wired to any `exports.*` (GameEngine.simulateJunkbot/walk/hurtJunkbot/findLinkedTeleportIndex
    // are what actually run, via engineTick).
}

let dropletType: JSString = "droplet"
let binType: JSString = "bin"
let junkbotType: JSString = "junkbot"
let gearbotType: JSString = "gearbot"
let climbbotType: JSString = "climbbot"
let flybotType: JSString = "flybot"
let eyebotType: JSString = "eyebot"
let crateType: JSString = "crate"
let teleportType: JSString = "teleport"
let fanType: JSString = "fan"
let laserType: JSString = "laser"
let levelBoundsType: JSString = "levelBounds"
let switchType: JSString = "switch"
let fireType: JSString = "fire"
let shieldType: JSString = "shield"
let jumpType: JSString = "jump"

let TELEPORT_COOLDOWN: Int32 = 50
let TELEPORT_EFFECT_PERIOD: Int32 = 20

func engineEntityType(_ jsType: JSString?) -> EntityType {
    if jsType == "brick" { return .brick }
    if jsType == junkbotType { return .junkbot }
    if jsType == gearbotType { return .gearbot }
    if jsType == climbbotType { return .climbbot }
    if jsType == flybotType { return .flybot }
    if jsType == eyebotType { return .eyebot }
    if jsType == binType { return .bin }
    if jsType == crateType { return .crate }
    if jsType == fireType { return .fire }
    if jsType == fanType { return .fan }
    if jsType == switchType { return .switch }
    if jsType == "pipe" { return .pipe }
    if jsType == shieldType { return .shield }
    if jsType == teleportType { return .teleport }
    if jsType == laserType { return .laser }
    if jsType == jumpType { return .jump }
    if jsType == dropletType { return .droplet }
    return .unknown
}

func engineEntityTypeName(_ type: EntityType) -> JSValue {
    switch type {
    case .brick: return "brick".jsValue
    case .junkbot: return "junkbot".jsValue
    case .gearbot: return "gearbot".jsValue
    case .climbbot: return "climbbot".jsValue
    case .flybot: return "flybot".jsValue
    case .eyebot: return "eyebot".jsValue
    case .bin: return "bin".jsValue
    case .crate: return "crate".jsValue
    case .fire: return "fire".jsValue
    case .fan: return "fan".jsValue
    case .switch: return "switch".jsValue
    case .pipe: return "pipe".jsValue
    case .shield: return "shield".jsValue
    case .teleport: return "teleport".jsValue
    case .laser: return "laser".jsValue
    case .jump: return "jump".jsValue
    case .droplet: return "droplet".jsValue
    case .levelBounds: return "levelBounds".jsValue
    case .unknown: return "unknown".jsValue
    }
}

func engineSoundName(_ id: Int32) -> JSValue? {
    switch id {
    case 0: return "turn".jsValue
    case 1: return "blockPickUp".jsValue
    case 2: return "blockDrop".jsValue
    case 3: return "blockClick".jsValue
    case 4: return "fall".jsValue
    case 5: return "headBonk".jsValue
    case 6: return "collectBin".jsValue
    case 7: return "collectBin2".jsValue
    case 8: return "switchClick".jsValue
    case 9: return "switchOn".jsValue
    case 10: return "switchOff".jsValue
    case 11: return "deathByFire".jsValue
    case 12: return "deathByWater".jsValue
    case 13: return "deathByLaser".jsValue
    case 14: return "deathByBot".jsValue
    case 15: return "getShield".jsValue
    case 16: return "getPowerup".jsValue
    case 17: return "losePowerup".jsValue
    case 18: return "teleport".jsValue
    case 22: return "jump".jsValue
    case 23: return "fan".jsValue
    case 24: return "drip0".jsValue
    case 25: return "drip1".jsValue
    case 26: return "drip2".jsValue
    case 27: return "undo".jsValue
    default: return nil
    }
}

func deleteJSProperty(_ object: JSObject, _ property: String) {
    _ = window.Reflect.deleteProperty(object, property)
}

func int32Property(_ object: JSObject, _ name: String, default defaultValue: Int32 = 0) -> Int32 {
    Int32(object[name].number ?? Double(defaultValue))
}

func boolProperty(_ object: JSObject, _ name: String) -> Bool {
    object[name].boolean == true
}

func entityType(_ e: JSObject) -> JSString? { e.type.jsString }

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
    JSClosure { args in gameEngine.rectanglesIntersectExport(args) }.jsValue

func levelBoundsObject(from entity: Entity) -> JSValue {
    let obj = JSObject.global.Object.function!.new()
    obj.type = "levelBounds".jsValue
    obj.x = entity.x.jsValue
    obj.y = entity.y.jsValue
    obj.width = entity.width.jsValue
    obj.height = entity.height.jsValue
    return obj.jsValue
}

func rectangleLevelBoundsCollisionObject(x: Int32, y: Int32, width: Int32, height: Int32) -> JSValue? {
    if let bounds = gameEngine.rectangleLevelBoundsCollision(x: x, y: y, width: width, height: height) {
        return levelBoundsObject(from: bounds)
    }
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
        if gameEngine.rectanglesIntersect(x, y, width, height, ox, oy, ow, oh) {
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
        if gameEngine.rectanglesIntersect(x, y, width, height, ox, oy, ow, oh) {
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
    JSClosure { args in gameEngine.rectangleLevelBoundsCollisionTestExport(args) }.jsValue

exports.rectangleCollisionTest =
    JSClosure { args in gameEngine.rectangleCollisionTestExport(args) }.jsValue

exports.rectangleCollisionAll =
    JSClosure { args in gameEngine.rectangleCollisionAllExport(args) }.jsValue

exports.raycast =
    JSClosure { args in gameEngine.raycastExport(args) }.jsValue

exports.worldToCanvas =
    JSClosure { args in gameEngine.worldToCanvasExport(args) }.jsValue

exports.canvasToWorld =
    JSClosure { args in gameEngine.canvasToWorldExport(args) }.jsValue

exports.sortEntitiesForRendering =
    JSClosure { args in gameEngine.sortEntitiesForRenderingExport(args) }.jsValue

exports.winOrLose =
    JSClosure { args in gameEngine.winOrLoseExport(args) }.jsValue

exports.rebuildAccelerationStructures =
    JSClosure { args in gameEngine.rebuildAccelerationStructuresExport(args) }.jsValue

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
    JSClosure { args in gameEngine.connectsExport(args) }.jsValue

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
    JSClosure { args in gameEngine.connectsToFixedExport(args) }.jsValue

exports.allConnectedToFixed =
    JSClosure { args in gameEngine.allConnectedToFixedExport(args) }.jsValue

// Finds the group(s) of unfixed bricks that would move together if `brick` were grabbed and
// dragged, in each of the two possible directions (attached bricks above it / below it). Mirrors
// the original JS's `possibleGrabs`' inner `findAttached` recursive traversal; the editor-specific
// policy (ctrl-click, multi-select, bypassing fixed/grabbable checks while editing) stays in JS.
func possibleGrabsCore(
    brick: JSObject, entitiesByTopY: JSObject, entitiesByBottomY: JSObject
) -> (canGrabDownward: Bool, grabDownward: [JSObject], canGrabUpward: Bool, grabUpward: [JSObject]) {
    func findAttached(_ start: JSObject, direction: Int32, attached: inout [JSObject], topLevel: Bool) -> Bool {
        let sy = Int32(start.y.number ?? 0), sh = Int32(start.height.number ?? 0)
        let candidates = yBucket(entitiesByTopY, sy + sh) + yBucket(entitiesByBottomY, sy)
        for otherValue in candidates {
            guard let entity = otherValue.object, entity != start else { continue }
            let entityIsBrick = entityType(entity) == "brick"
            guard entitiesConnect(start, entity, direction: entityIsBrick ? direction : -1) else { continue }
            if attached.contains(where: { $0 == entity }) { continue }
            if entity.fixed.boolean == true || !entityIsBrick {
                return false
            }
            attached.append(entity)
            if !findAttached(entity, direction: direction, attached: &attached, topLevel: false) {
                return false
            }
        }
        if topLevel {
            for brickInGroup in attached {
                let bx = Int32(brickInGroup.x.number ?? 0), by = Int32(brickInGroup.y.number ?? 0)
                let bw = Int32(brickInGroup.width.number ?? 0), bh = Int32(brickInGroup.height.number ?? 0)
                let candidates2 = yBucket(entitiesByTopY, by + bh) + yBucket(entitiesByBottomY, by)
                for otherValue in candidates2 {
                    guard let entity = otherValue.object else { continue }
                    let entType = entityType(entity)
                    guard entity.fixed.boolean != true,
                        entType == "brick" || entType == "jump" || entType == "shield"
                    else { continue }
                    let ex = Int32(entity.x.number ?? 0), ew = Int32(entity.width.number ?? 0)
                    guard bx + bw > ex && bx < ex + ew else { continue }
                    if attached.contains(where: { $0 == entity }) { continue }
                    if connectsToFixedCore(
                        startEntity: entity, entitiesByTopY: entitiesByTopY, entitiesByBottomY: entitiesByBottomY,
                        direction: 0, ignoreEntities: attached)
                    {
                        continue
                    }
                    let ey = Int32(entity.y.number ?? 0)
                    var blocked = false
                    for junkValue in yBucket(entitiesByBottomY, ey) {
                        guard let junk = junkValue.object, entityType(junk) != "brick" else { continue }
                        let jx = Int32(junk.x.number ?? 0), jw = Int32(junk.width.number ?? 0)
                        if ex + ew > jx && ex < jx + jw {
                            blocked = true
                            break
                        }
                    }
                    if blocked { return false }
                    attached.append(entity)
                }
            }
        }
        return true
    }

    var grabDownward: [JSObject] = [brick]
    var grabUpward: [JSObject] = [brick]
    let canGrabDownward = findAttached(brick, direction: 1, attached: &grabDownward, topLevel: true)
    let canGrabUpward = findAttached(brick, direction: -1, attached: &grabUpward, topLevel: true)
    return (canGrabDownward, grabDownward, canGrabUpward, grabUpward)
}

exports.possibleGrabs =
    JSClosure { args in
        guard let brick = args[0].object, let entitiesByTopY = args[1].object,
            let entitiesByBottomY = args[2].object
        else { return .undefined }
        let result = possibleGrabsCore(
            brick: brick, entitiesByTopY: entitiesByTopY, entitiesByBottomY: entitiesByBottomY)
        let obj = JSObject.global.Object.function!.new()
        obj.canGrabDownward = result.canGrabDownward.jsValue
        obj.canGrabUpward = result.canGrabUpward.jsValue
        obj.grabDownward = result.grabDownward.map { $0.jsValue }.jsValue
        obj.grabUpward = result.grabUpward.map { $0.jsValue }.jsValue
        return obj.jsValue
    }.jsValue

exports.findMisplacedEntities =
    JSClosure { args in gameEngine.findMisplacedEntitiesExport(args) }.jsValue

// Debug-overlay validity/collision checks for the given `entities` array (the "Problem Sleuth"),
// mirroring the original JS's `detectProblems`. Returns raw `{kind, entity, otherEntity?, worldX?,
// worldY?}` records rather than formatted messages, so message text stays in JS (no native Swift
// String formatting needed here) — see `detectProblems` in src/game.js for how these get turned
// into display strings. The playback/recording desync check from the original stays JS-side too,
// since it compares against JS-only `playbackLevel` state that has no GameEngine equivalent.
func detectProblemsExport(_ args: [JSValue]) -> JSValue {
    guard let entities = args[0].object else { return [JSValue]().jsValue }
    let length = Int(entities.length.number ?? 0)
    let values = (0..<length).map { entities[$0] }

    func makeResult(
        kind: String, entity: JSValue, otherEntity: JSValue? = nil,
        worldX: Int32? = nil, worldY: Int32? = nil
    ) -> JSValue {
        let obj = JSObject.global.Object.function!.new()
        obj.kind = kind.jsValue
        obj.entity = entity
        if let otherEntity { obj.otherEntity = otherEntity }
        if let worldX { obj.worldX = worldX.jsValue }
        if let worldY { obj.worldY = worldY.jsValue }
        return obj.jsValue
    }

    var results: [JSValue] = []
    for i in 0..<length {
        guard let entity = values[i].object else { continue }

        // Reading straight from loosely-typed JS objects (unlike a native Swift `Entity`, whose
        // Int32 fields can't be NaN/non-numeric by construction), so these validity checks are
        // still meaningful here and are kept faithful to the original.
        guard let xNum = entity.x.number, xNum.isFinite, let yNum = entity.y.number, yNum.isFinite
        else {
            results.append(makeResult(kind: "invalidPosition", entity: values[i]))
            continue
        }
        let ex = Int32(xNum), ey = Int32(yNum)

        if ex % CELL_W != 0 {
            results.append(makeResult(kind: "misaligned", entity: values[i]))
            continue
        }

        guard let wNum = entity.width.number, wNum.isFinite, let hNum = entity.height.number,
            hNum.isFinite
        else {
            results.append(makeResult(kind: "invalidSize", entity: values[i]))
            continue
        }
        let ew = Int32(wNum), eh = Int32(hNum)

        if entityType(entity) == "brick" {
            guard let widthInStudsNum = entity.widthInStuds.number, widthInStudsNum.isFinite else {
                results.append(makeResult(kind: "invalidWidthInStuds", entity: values[i]))
                continue
            }
            let widthInStuds = Int32(widthInStudsNum)
            if ew != CELL_W * widthInStuds {
                results.append(makeResult(kind: "widthMismatch", entity: values[i]))
                continue
            }
        }
        for j in (i + 1)..<length {
            guard let other = values[j].object else { continue }
            let ox = Int32(other.x.number ?? 0), oy = Int32(other.y.number ?? 0)
            let ow = Int32(other.width.number ?? 0), oh = Int32(other.height.number ?? 0)
            if gameEngine.rectanglesIntersect(ex, ey, ew, eh, ox, oy, ow, oh) {
                let worldX = (ex + ox + (ew + ow) / 2) / 2
                let worldY = (ey + oy + (eh + oh) / 2) / 2
                results.append(
                    makeResult(
                        kind: "collision", entity: values[i], otherEntity: values[j],
                        worldX: worldX, worldY: worldY))
            }
        }
    }
    return results.jsValue
}

exports.detectProblems =
    JSClosure { args in detectProblemsExport(args) }.jsValue

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
    JSClosure { args in gameEngine.makeEntityExport("brick", args) }.jsValue

exports.makeJunkbot =
    JSClosure { args in gameEngine.makeEntityExport(junkbotType, args) }.jsValue

exports.makeGearbot =
    JSClosure { args in gameEngine.makeEntityExport(gearbotType, args) }.jsValue

exports.makeClimbbot =
    JSClosure { args in gameEngine.makeEntityExport(climbbotType, args) }.jsValue

exports.makeFlybot =
    JSClosure { args in gameEngine.makeEntityExport(flybotType, args) }.jsValue

exports.makeEyebot =
    JSClosure { args in gameEngine.makeEntityExport(eyebotType, args) }.jsValue

exports.makeBin =
    JSClosure { args in gameEngine.makeEntityExport(binType, args) }.jsValue

exports.makeCrate =
    JSClosure { args in gameEngine.makeEntityExport(crateType, args) }.jsValue

exports.makeFire =
    JSClosure { args in gameEngine.makeEntityExport(fireType, args) }.jsValue

exports.makeFan =
    JSClosure { args in gameEngine.makeEntityExport(fanType, args) }.jsValue

exports.makeLaser =
    JSClosure { args in gameEngine.makeEntityExport(laserType, args) }.jsValue

exports.makeSwitch =
    JSClosure { args in gameEngine.makeEntityExport(switchType, args) }.jsValue

exports.makeTeleport =
    JSClosure { args in gameEngine.makeEntityExport(teleportType, args) }.jsValue

exports.makeJump =
    JSClosure { args in gameEngine.makeEntityExport(jumpType, args) }.jsValue

exports.makeShield =
    JSClosure { args in gameEngine.makeEntityExport(shieldType, args) }.jsValue

exports.makePipe =
    JSClosure { args in gameEngine.makeEntityExport("pipe", args) }.jsValue

exports.makeDroplet =
    JSClosure { args in gameEngine.makeEntityExport(dropletType, args) }.jsValue

func engineEntity(from object: JSObject) -> Entity {
    var entity = Entity(
        id: int32Property(object, "id"),
        type: engineEntityType(entityType(object)),
        x: int32Property(object, "x"),
        y: int32Property(object, "y"),
        width: int32Property(object, "width"),
        height: int32Property(object, "height"))

    entity.grabbed = boolProperty(object, "grabbed")
    entity.fixed = boolProperty(object, "fixed")
    entity.floating = boolProperty(object, "floating")
    entity.wasFloating = boolProperty(object, "wasFloating")
    entity.removeBeforeRender = boolProperty(object, "removeBeforeRender")
    entity.facing = int32Property(object, "facing", default: 1)
    entity.facingY = int32Property(object, "facingY")
    entity.animationFrame = int32Property(object, "animationFrame")
    entity.widthInStuds = int32Property(object, "widthInStuds", default: max(1, int32Property(object, "width") / CELL_W))
    entity.armored = boolProperty(object, "armored")
    entity.losingShield = boolProperty(object, "losingShield")
    entity.losingShieldTime = int32Property(object, "losingShieldTime")
    entity.gettingShield = boolProperty(object, "gettingShield")
    entity.dying = boolProperty(object, "dying")
    entity.dyingFromWater = boolProperty(object, "dyingFromWater")
    entity.dead = boolProperty(object, "dead")
    entity.collectingBin = boolProperty(object, "collectingBin")
    entity.headLoaded = boolProperty(object, "headLoaded")
    entity.momentumX = int32Property(object, "momentumX")
    entity.momentumY = int32Property(object, "momentumY")
    entity.scaredy = boolProperty(object, "scaredy")
    entity.on = boolProperty(object, "on")
    entity.used = boolProperty(object, "used")
    entity.switchID = int32Property(object, "switchID", default: -1)
    entity.teleportID = int32Property(object, "teleportID", default: -1)
    entity.timer = int32Property(object, "timer")
    entity.blocked = boolProperty(object, "blocked")
    entity.energy = int32Property(object, "energy")
    entity.active = boolProperty(object, "active")
    entity.activeTimer = int32Property(object, "activeTimer")
    entity.splashing = boolProperty(object, "splashing")

    if let grabOffset = object.grabOffset.object {
        entity.grabOffsetX = int32Property(grabOffset, "x")
        entity.grabOffsetY = int32Property(grabOffset, "y")
    }
    return entity
}

func existingEntityObject(id: Int32, in values: [JSValue]) -> JSValue? {
    for value in values {
        if Int32(value.object?.id.number ?? -1) == id {
            return value
        }
    }
    return nil
}

func syncEntity(_ entity: Entity, to object: JSObject) {
    object.id = entity.id.jsValue
    object.type = engineEntityTypeName(entity.type)
    object.x = entity.x.jsValue
    object.y = entity.y.jsValue
    object.width = entity.width.jsValue
    object.height = entity.height.jsValue
    object.fixed = entity.fixed.jsValue
    object.facing = entity.facing.jsValue
    object.facingY = entity.facingY.jsValue
    object.animationFrame = entity.animationFrame.jsValue

    if entity.type == .brick {
        object.widthInStuds = entity.widthInStuds.jsValue
    }
    if entity.type == .junkbot {
        object.armored = entity.armored.jsValue
        object.losingShield = entity.losingShield.jsValue
        object.losingShieldTime = entity.losingShieldTime.jsValue
        object.gettingShield = entity.gettingShield.jsValue
        object.dying = entity.dying.jsValue
        object.dyingFromWater = entity.dyingFromWater.jsValue
        object.dead = entity.dead.jsValue
        object.collectingBin = entity.collectingBin.jsValue
        object.headLoaded = entity.headLoaded.jsValue
        object.momentumX = entity.momentumX.jsValue
        object.momentumY = entity.momentumY.jsValue
    }
    if entity.type == .bin {
        object.scaredy = entity.scaredy.jsValue
    }
    if entity.type == .fire || entity.type == .fan || entity.type == .laser || entity.type == .switch {
        object.on = entity.on.jsValue
        object.switchID = entity.switchID.jsValue
    }
    if entity.type == .shield {
        object.used = entity.used.jsValue
    }
    if entity.type == .teleport {
        object.teleportID = entity.teleportID.jsValue
        object.timer = entity.timer.jsValue
        object.blocked = entity.blocked.jsValue
    }
    if entity.type == .pipe {
        object.timer = entity.timer.jsValue
    }
    if entity.type == .jump {
        object.active = entity.active.jsValue
    }
    if entity.type == .climbbot {
        object.energy = entity.energy.jsValue
    }
    if entity.type == .eyebot {
        object.activeTimer = entity.activeTimer.jsValue
    }
    if entity.type == .droplet {
        object.splashing = entity.splashing.jsValue
    }

    if entity.grabbed {
        object.grabbed = .boolean(true)
        let offset = object.grabOffset.object ?? JSObject.global.Object.function!.new()
        offset.x = entity.grabOffsetX.jsValue
        offset.y = entity.grabOffsetY.jsValue
        object.grabOffset = offset.jsValue
    } else {
        deleteJSProperty(object, "grabbed")
        deleteJSProperty(object, "grabOffset")
    }
    if entity.floating {
        object.floating = .boolean(true)
    } else {
        deleteJSProperty(object, "floating")
    }
    if entity.wasFloating {
        object.wasFloating = .boolean(true)
    } else {
        deleteJSProperty(object, "wasFloating")
    }
    if entity.removeBeforeRender {
        object.removeBeforeRender = .boolean(true)
    } else {
        deleteJSProperty(object, "removeBeforeRender")
    }
}

func syncEngineEntities(to entitiesArray: JSObject) {
    let previousLength = Int(entitiesArray.length.number ?? 0)
    let previousValues = (0..<previousLength).map { entitiesArray[$0] }
    var outputIndex = 0
    for entity in gameEngine.entities {
        let value = existingEntityObject(id: entity.id, in: previousValues) ?? JSObject.global.Object.function!.new().jsValue
        if let object = value.object {
            syncEntity(entity, to: object)
            entitiesArray[outputIndex] = object.jsValue
            outputIndex += 1
        }
    }
    entitiesArray.length = outputIndex.jsValue
}

func syncEngineEffects(entities: JSObject, wind: JSObject, laserBeams: JSObject, teleportEffects: JSObject) {
    wind.length = .number(0)
    let entityValues = (0..<Int(entities.length.number ?? 0)).map { entities[$0] }
    for effect in gameEngine.wind {
        guard effect.fanEntityIndex >= 0, effect.fanEntityIndex < gameEngine.entities.count else { continue }
        let fanID = gameEngine.entities[effect.fanEntityIndex].id
        guard let fan = existingEntityObject(id: fanID, in: entityValues) else { continue }
        let entry = JSObject.global.Object.function!.new()
        entry.fan = fan
        var extents: [JSValue] = []
        for i in 0..<effect.numExtents {
            extents.append(effect.extent(at: i).jsValue)
        }
        entry.extents = extents.jsValue
        _ = wind.push!(entry.jsValue)
    }

    laserBeams.length = .number(0)
    for beam in gameEngine.laserBeams {
        guard beam.laserEntityIndex >= 0, beam.laserEntityIndex < gameEngine.entities.count else { continue }
        let laserID = gameEngine.entities[beam.laserEntityIndex].id
        guard let laser = existingEntityObject(id: laserID, in: entityValues) else { continue }
        let entry = JSObject.global.Object.function!.new()
        entry.laserBrick = laser
        entry.extent = beam.extent.jsValue
        if beam.hitEntityIndex >= 0, beam.hitEntityIndex < gameEngine.entities.count {
            let hitID = gameEngine.entities[beam.hitEntityIndex].id
            entry.hitWhat = existingEntityObject(id: hitID, in: entityValues) ?? .undefined
        } else {
            entry.hitWhat = .undefined
        }
        _ = laserBeams.push!(entry.jsValue)
    }

    teleportEffects.length = .number(0)
    for effect in gameEngine.teleportEffects {
        let entry = JSObject.global.Object.function!.new()
        entry.x = effect.x.jsValue
        entry.y = effect.y.jsValue
        entry.frameIndex = effect.frameIndex.jsValue
        _ = teleportEffects.push!(entry.jsValue)
    }
}

func engineLevelState(from level: JSObject) -> (entities: [Entity], bounds: LevelBounds?) {
    guard let entities = level.entities.object else { return ([], nil) }

    var nativeEntities: [Entity] = []
    let length = Int(entities.length.number ?? 0)
    nativeEntities.reserveCapacity(length)
    for i in 0..<length {
        guard let object = entities[i].object else { continue }
        nativeEntities.append(engineEntity(from: object))
    }

    let bounds: LevelBounds?
    if let levelBounds = level.bounds.object {
        bounds = LevelBounds(
            x: int32Property(levelBounds, "x"),
            y: int32Property(levelBounds, "y"),
            width: int32Property(levelBounds, "width"),
            height: int32Property(levelBounds, "height"))
    } else {
        bounds = nil
    }

    return (nativeEntities, bounds)
}

exports.engineLoadLevel =
    JSClosure { args in gameEngine.engineLoadLevelExport(args) }.jsValue

exports.engineTick =
    JSClosure { args in gameEngine.engineTickExport(args) }.jsValue

// Play-mode drag-and-drop, routed through GameEngine's persistent `entities` (see
// `Sources/JunkbotCore/Input.swift`). Editor-mode dragging stays JS-side (unchanged); the JS
// caller only invokes these while `!editing`. Position updates land directly on
// `gameEngine.entities`, then reach JS's read-only mirror via the next `engineTick`'s
// `syncEngineEntities` (mirror-and-sync, same as every other tick-driven state change) — these
// exports don't sync entities themselves.
exports.mouseDown =
    JSClosure { args in
        gameEngine.mouseDown(Int32(args[0].number ?? 0), Int32(args[1].number ?? 0))
        return .undefined
    }.jsValue

exports.mouseMove =
    JSClosure { args in
        gameEngine.mouseMove(Int32(args[0].number ?? 0), Int32(args[1].number ?? 0))
        return .undefined
    }.jsValue

exports.mouseUp =
    JSClosure { args in
        gameEngine.mouseUp(Int32(args[0].number ?? 0), Int32(args[1].number ?? 0))
        return .undefined
    }.jsValue

exports.isDragging =
    JSClosure { _ in .boolean(gameEngine.isDragging) }.jsValue

// Play-mode undo (see Sources/JunkbotCore/Undo.swift) — a separate, new capability from the
// level editor's own undo/redo (JS-side, JSON-snapshot based, `editing`-gated, untouched).
exports.undo =
    JSClosure { _ in .boolean(gameEngine.undo()) }.jsValue

exports.canUndo =
    JSClosure { _ in .boolean(gameEngine.canUndo) }.jsValue

// Play-mode rewind (see Sources/JunkbotCore/Undo.swift), replacing the old JS-side
// jsondiffpatch-based `playbackLevel`/`levelLastFrame` scrubbing.
exports.beginRewind =
    JSClosure { _ in
        gameEngine.beginRewind()
        return .undefined
    }.jsValue

exports.stepRewind =
    JSClosure { _ in .boolean(gameEngine.stepRewind()) }.jsValue

exports.endRewind =
    JSClosure { _ in
        gameEngine.endRewind()
        return .undefined
    }.jsValue

// undo()/stepRewind() mutate gameEngine.entities directly, bypassing the usual
// tick() -> syncEngineEntities path (and both can run while paused, so no
// engineTick call happens on its own to refresh JS's mirror). JS calls this once right after
// undo()/stepRewind() return true, reusing the same sync logic engineTick already uses.
exports.syncEngineState =
    JSClosure { args in
        guard let entities = args[0].object, let wind = args[1].object, let laserBeams = args[2].object,
            let teleportEffects = args[3].object
        else { return .undefined }
        syncEngineEntities(to: entities)
        syncEngineEffects(entities: entities, wind: wind, laserBeams: laserBeams, teleportEffects: teleportEffects)
        let result = JSObject.global.Object.function!.new()
        result.frameCounter = gameEngine.frameCounter.jsValue
        result.moves = gameEngine.moves.jsValue
        return result.jsValue
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
