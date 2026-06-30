import JavaScriptKit
import JavaScriptEventLoop

func loadJSON(path: String) async throws -> JSValue {
    let fetch = JSObject.global.fetch.function!
    let res = try await JSPromise(from: fetch(path))!.value
    if res.ok.boolean == false { throw JSValueError(message: "HTTP \(res.status.number ?? 0)") }
    return try await JSPromise(from: res.json().function!())!.value
}

func loadAtlasJSON(path: String) async throws -> JSValue {
    let fetch = JSObject.global.fetch.function!
    let res = try await JSPromise(from: fetch(path))!.value
    let data = try await JSPromise(from: res.json().function!())!.value
    let frames = data.frames
    let animations = data.animations
    let result = JSObject.global.Object.function!.new()
    let keys = JSObject.global.Object.keys(animations)
    let len = Int(keys.length.number ?? 0)
    let regex = JSObject.global.RegExp.function!.new("\\.png", "i")
    for i in 0..<len {
        let name = keys[i].string!
        let cleanName = name.object!.replace(regex, "")
        let frameIndex = animations[dynamicMember: name][0]
        let bounds = frames[dynamicMember: frameIndex.string!]
        let obj = JSObject.global.Object.function!.new()
        obj.bounds = bounds
        result[dynamicMember: cleanName.string!] = obj.jsValue
    }
    return result.jsValue
}

func loadTextFile(path: String) async throws -> JSValue {
    let fetch = JSObject.global.fetch.function!
    let res = try await JSPromise(from: fetch(path))!.value
    if res.ok.boolean == false { throw JSValueError(message: "HTTP \(res.status.number ?? 0)") }
    return try await JSPromise(from: res.text().function!())!.value
}

func loadLevelFromTextFile(path: String, game: JSValue) async throws -> JSValue {
    let fetch = JSObject.global.fetch.function!
    let res = try await JSPromise(from: fetch(path))!.value
    return try await JSPromise(from: res.text().function!())!.value
}

func loadSound(path: String, audioCtx: JSValue) async throws -> JSValue {
    let fetch = JSObject.global.fetch.function!
    let res = try await JSPromise(from: fetch(path))!.value
    if res.ok.boolean == false { throw JSValueError(message: "HTTP \(res.status.number ?? 0)") }
    let buf = try await JSPromise(from: res.arrayBuffer().function!())!.value
    return try await JSPromise(from: audioCtx.decodeAudioData(buf))!.value
}

func loadLevelListing(path: String) async throws -> JSValue {
    let fetch = JSObject.global.fetch.function!
    let res = try await JSPromise(from: fetch(path))!.value
    let text = try await JSPromise(from: res.text().function!())!.value
    let trimmed = text.object!.trim()
    let regex = JSObject.global.RegExp.function!.new("\\r?\\n", "g")
    let lines = trimmed.object!.split(regex)
    let mapFunc = JSClosure { args in return args[0].object!.trim() }
    defer { mapFunc.release() }
    return lines.object!.map(mapFunc)
}

struct JSValueError: Error {
    let message: String
}

func loadResource(path: String) async throws -> JSValue {
    if JSObject.global.RegExp.function!.new("spritesheets/.*\\.json$", "i").test!(path).boolean == true {
        return try await loadAtlasJSON(path: path)
    } else if JSObject.global.RegExp.function!.new("\\.json$", "i").test!(path).boolean == true {
        return try await loadJSON(path: path)
    } else if JSObject.global.RegExp.function!.new("level\\.listing\\.txt$", "i").test!(path).boolean == true {
        return try await loadLevelListing(path: path)
    } else if JSObject.global.RegExp.function!.new("levels/.*\\.txt$", "i").test!(path).boolean == true {
        return try await loadLevelFromTextFile(path: path, game: .undefined)
    } else if JSObject.global.RegExp.function!.new("\\.(ogg|mp3|wav)$", "i").test!(path).boolean == true {
        return try await loadSound(path: path, audioCtx: audioCtx)
    } else if JSObject.global.RegExp.function!.new("\\.(png|jpe?g|gif)$", "i").test!(path).boolean == true {
        // loadImage in main.swift is synchronous and returns a promise natively. Let's await it.
        let p = loadImage(path)
        return try await JSPromise(from: p)!.value
    }
    return .undefined
}

func loadResources(resourcePathsByID: JSValue) async throws -> JSValue {
    let entries = JSObject.global.Object.entries(resourcePathsByID)
    let length = Int(entries.length.number ?? 0)
    var silenceErrors = false
    
    // We do them concurrently with a throwing task group
    let results = try await withThrowingTaskGroup(of: (String, JSValue).self) { group in
        for i in 0..<length {
            let entry = entries[i]
            let id = entry[0].string!
            let path = entry[1].string!
            
            group.addTask {
                var resource: JSValue = .undefined
                do {
                    resource = try await loadResource(path: path)
                } catch {
                    if !silenceErrors {
                        if JSObject.global.location.protocol.string == "file:" {
                            _ = showErrorMessage.callAsFunction(this: JSValue.null, .string("This page must be served by a web server..."), (error as? JSValueError)?.message.jsValue ?? .undefined)
                            silenceErrors = true
                        } else {
                            _ = showErrorMessage.callAsFunction(this: JSValue.null, .string("Failed to load resource '\(path)'"), (error as? JSValueError)?.message.jsValue ?? .undefined)
                        }
                    }
                }
                // Need to update global variables carefully, actor might be needed but in single-threaded Embedded Swift Wasm, we can just update them. Wait, TaskGroup executes concurrently, in Wasm it is cooperative so it's safe.
                loadedResources += 1
                if (loadedResources / totalResources * Double(numProgressBricks)) > Double(progressBricks.count) {
                    let progressBrick = JSObject.global.document.createElement("div")
                    _ = progressBrick.classList.add("load-progress-brick")
                    progressBricks.append(progressBrick)
                    _ = loadProgress.appendChild!(progressBrick)
                }
                return (id, resource)
            }
        }
        
        let resultObj = JSObject.global.Object.function!.new()
        for try await (id, resource) in group {
            resultObj[dynamicMember: id] = resource
        }
        return resultObj.jsValue
    }
    return results
}


func loadAllLevels(games: JSValue) async throws -> JSValue {
    let getLevelListsFunc = JSObject.global.getLevelLists.function!
    let lists = getLevelListsFunc(resources)
    var promises = JSObject.global.Array.function!.new()
    
    // In original: for (const { game, levelNames } of getLevelLists(resources)) ...
    let len = Int(lists.length.number ?? 0)
    for i in 0..<len {
        let listObj = lists[i]
        let gameVal = listObj.game
        let levelNames = listObj.levelNames
        
        let includesFunc = games.includes.function!
        if includesFunc.callAsFunction(this: games, gameVal).boolean == true {
            let namesLen = Int(levelNames.length.number ?? 0)
            for j in 0..<namesLen {
                let levelName = levelNames[j]
                
                let levelArgs = JSObject.global.Object.function!.new()
                levelArgs.game = gameVal
                levelArgs.levelName = levelName
                
                // loadLevelByName is a JS Promise returning func in main.swift. Wait, no, it's a JS string function.
                let p = loadLevelByName.callAsFunction(this: JSValue.null, levelArgs)
                _ = promises.push!(p)
            }
        }
    }
    
    return try await JSPromise(from: JSObject.global.Promise.all!(promises))!.value
}

func gatherStatistics(games: JSValue) async throws -> JSValue {
    let occurrencesPerEntityType = JSObject.global.Object.function!.new()
    let levelsPerEntityType = JSObject.global.Object.function!.new()
    
    let levels = try await loadAllLevels(games: games)
    let len = Int(levels.length.number ?? 0)
    for i in 0..<len {
        let level = levels[i]
        let recordedTypesInThisLevel = JSObject.global.Array.function!.new()
        
        let entities = level.entities
        let entsLen = Int(entities.length.number ?? 0)
        for j in 0..<entsLen {
            let entity = entities[j]
            let entityType = entity.type
            
            let indexOfFunc = recordedTypesInThisLevel.indexOf.function!
            if indexOfFunc.callAsFunction(this: recordedTypesInThisLevel, entityType).number == -1.0 {
                _ = recordedTypesInThisLevel.push!(entityType)
                let prevLevels = levelsPerEntityType[dynamicMember: entityType.string ?? ""].number ?? 0.0
                levelsPerEntityType[dynamicMember: entityType.string ?? ""] = .number(prevLevels + 1.0)
            }
            
            let prevOcc = occurrencesPerEntityType[dynamicMember: entityType.string ?? ""].number ?? 0.0
            occurrencesPerEntityType[dynamicMember: entityType.string ?? ""] = .number(prevOcc + 1.0)
        }
    }
    // original just does something, not returning? In JS, it was async. We return undefined.
    return .undefined
}

