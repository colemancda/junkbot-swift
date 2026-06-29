// Translated from Lingo: parent_game manager.ls

public class GameManager {
    public var gameState: String = "#PREGAME"
    public var currentLevel: LV = .void
    public var currentLevelIndex: Int = 1
    public var levelList: LingoList? = nil

    public init() {
        gameState = "#PREGAME"
        prepareLevelMenu()
    }

    public func prepareLevelMenu() {
        let firstBuilding = PropList()
        firstBuilding["state"] = .string("#open")
        firstBuilding["LEVELS"] = .list(LingoList())
        let buildingList = LingoList()
        buildingList.add(.propList(firstBuilding))
        Glob.shared["building"] = .list(buildingList)

        var building = 1
        var level = 1
        // NOTE: Lingo iterates castMembers of castLib "levels"; stub out here
        let castMemberCount = 0 // stub: number of castMembers of castLib "levels"
        for _ in 1...max(1, castMemberCount) {
            // levelmem = member(n, "levels") -- stub
            // leveldata = Glob.shared.config_manager.parseParams(levelmem.text) -- stub
            // leveldata.info.title = Glob.shared.config_manager.restoreCommas(leveldata.info.title)
            // leveldata.info.hint = Glob.shared.config_manager.restoreCommas(leveldata.info.hint)
            // Glob.shared.building[building].LEVELS[level] = [...]
            Glob.shared["keyrequired"] = .int(10)
            let current = PropList()
            current["building"] = .int(1)
            current["level"] = .int(1)
            current["moves"] = .int(0)
            Glob.shared["current"] = .propList(current)
            level += 1
            if level > 15 {
                level = 1
                building += 1
                if let buildingLV = Glob.shared["building"].asList {
                    while buildingLV.count < building {
                        let b = PropList()
                        b["state"] = .string("#locked")
                        b["LEVELS"] = .list(LingoList())
                        buildingLV.add(.propList(b))
                    }
                }
            }
            Glob.shared["plaque"] = .string("welcome")
        }
        Glob.shared["hof"] = .int(60)
        if let rankdata = Glob.shared["rankdata"].asPropList {
            rankdata["serverState"] = .string("#network")
        }
        // let record = Glob.shared.database_manager.getRecord() -- stub
        let record: PropList? = nil // stub
        if let record = record {
            decodeRecord(record)
        }
        totalKeys()
        if let rankdata = Glob.shared["rankdata"].asPropList,
           let keys = rankdata["keys"].asInt,
           let hof = Glob.shared["hof"].asInt,
           keys >= hof {
            rankdata["AlreadySawHOF"] = .string("#YES")
        }
    }

    public func encodeRecord() -> PropList {
        let rec = PropList()
        var state = 2
        var record = ""
        var total = 0
        guard let buildings = Glob.shared["building"].asList else { return rec }
        guard let current = Glob.shared["current"].asPropList else { return rec }
        let currentBuilding = current["building"].asInt ?? 0
        let currentLevelIdx = current["level"].asInt ?? 0
        let currentMoves = current["moves"].asInt ?? 0
        for bn in 0..<buildings.count {
            let bnIdx = bn + 1
            guard let b = buildings[bnIdx].asPropList else { continue }
            guard let levels = b["LEVELS"].asList else { continue }
            for ln in 0..<levels.count {
                let lnIdx = ln + 1
                guard let L = levels[lnIdx].asPropList else { continue }
                let mInt: Int
                if (bnIdx == currentBuilding) && (lnIdx == currentLevelIdx) {
                    mInt = currentMoves
                } else {
                    mInt = L["moves"].asInt ?? 0
                }
                if mInt == 0 {
                    state = 0
                    continue
                }
                total += mInt
                let goal = L["goal"].asInt ?? 0
                if (state > 0) && (mInt > goal) {
                    state = 1
                }
                let mStr: String
                if mInt > 999 {
                    mStr = "+"
                } else {
                    mStr = String(mInt)
                }
                let index = L["index"].asInt ?? 0
                record += "\(index) \(mStr),"
            }
        }
        // delete char -30000 of record — remove trailing comma
        if record.hasSuffix(",") {
            record.removeLast()
        }
        rec["state"] = .int(state)
        rec["total"] = .int(total)
        rec["record"] = .string(record)
        totalKeys()
        if let rankdata = Glob.shared["rankdata"].asPropList {
            rankdata["moves"] = .int(total)
        }
        return rec
    }

    public func decodeRecord(_ rec: PropList) {
        guard let recordStr = rec["record"].asString else { return }
        let items = recordStr.split(separator: ",")
        for entry in items {
            let trimmed = entry.drop(while: { $0 == " " })
            let parts = trimmed.split(separator: " ")
            guard parts.count >= 2,
                  let n = Int(parts[0]),
                  let m = Int(parts[1]) else { continue }
            let building = (n - 1) / 15 + 1
            let level = n - (15 * (building - 1))
            if let buildingList = Glob.shared["building"].asList,
               buildingList.count >= building,
               let b = buildingList[building].asPropList,
               let levels = b["LEVELS"].asList,
               levels.count >= level,
               let L = levels[level].asPropList {
                L["moves"] = .int(m)
            }
        }
        if let rankdata = Glob.shared["rankdata"].asPropList {
            rankdata["moves"] = rec["total"]
        }
    }

    public func setGame(_ L: LingoList) {
        levelList = L
        currentLevelIndex = 1
    }

    public func selectlevel() {
        exitGame()
        go("levels")
    }

    public func startGame() {
        go("play")
        startLevel()
    }

    public func restartLevel() {
        // Glob.shared.PLAYER.play_manager.leave()
        // Glob.shared.PLAYER.play_manager.setLevel(currentLevel)
        // Glob.shared.PLAYER.play_manager.startLevel()
    }

    public func pauseLevel(_ flag: Bool) {
        if gameState == "#INLEVEL" {
            // Glob.shared.PLAYER.play_manager.pauseLevel(flag)
        }
    }

    public func exitGame() {
        // Glob.shared.PLAYER.play_manager.leave()
        SndMusicEnd()
    }

    public func gameOverButton() {
        // Glob.shared.PLAYER.play_manager.leave()
        gameState = "#PREGAME"
        SndMusicEnd()
        // Glob.shared.download_manager.mainmenu()
    }

    public func callback(_ p: String) {
        switch p {
        case "#com_nextlevel":
            if let current = Glob.shared["current"].asPropList,
               let lv = current["level"].asInt {
                current["level"] = .int(lv + 1)
            }
            startLevel()
        case "#title_done":
            // Glob.shared.PLAYER.play_manager.startLevel()
            break
        case "#restart_level":
            startGame()
        case "#select_level":
            selectlevel()
        default:
            break
        }
    }

    public func endLevel(_ winOrLose: String) {
        SndMusicEnd()
        setCursor("#none")
        if winOrLose == "#WIN" {
            if let current = Glob.shared["current"].asPropList {
                // current["moves"] = Glob.shared.PLAYER.play_manager.gamestatus.moves
                _ = current
            }
            SndSFX("voice_ohyeah")
            intermission()
            // Glob.shared.database_manager.setRecord(encodeRecord())
        } else {
            loseGame()
        }
    }

    public func startLevel() {
        // Glob.shared.PLAYER.play_manager.leave()
        SndMusicStart("level\(lingoRandom(5))")
        if levelList == nil {
            guard let current = Glob.shared["current"].asPropList,
                  let buildingIdx = current["building"].asInt,
                  let levelIdx = current["level"].asInt,
                  let buildings = Glob.shared["building"].asList,
                  buildings.count >= buildingIdx,
                  let b = buildings[buildingIdx].asPropList,
                  let levels = b["LEVELS"].asList else { return }
            if levelIdx > levels.count {
                selectlevel()
            } else {
                guard let lvl = levels[levelIdx].asPropList else { return }
                currentLevel = lvl["data"]
                // Glob.shared.PLAYER.play_manager.setLevel(currentLevel)
                // Glob.shared.title_obj.updateData(...)
            }
        } else if let list = levelList {
            currentLevel = list[currentLevelIndex]
            // Glob.shared.PLAYER.play_manager.setLevel(currentLevel)
            // Glob.shared.PLAYER.play_manager.startLevel()
        }
    }

    public func loseGame() {
        SndMusicEnd()
        gameState = "#loseGame"
        // Glob.shared.fail_msg_obj.updateData()
    }

    public func finishGame() {
        SndMusicEnd()
        gameState = "#finishGame"
        // Glob.shared.PLAYER["signsprite"].showSign("signGameFinish", "#gameOverButton")
    }

    public func intermission() {
        gameState = "#INTERLEVEL"
        // Glob.shared["master_obj"].dropBox()
    }

    public func totalKeys() {
        var keys = 0
        guard let buildings = Glob.shared["building"].asList else { return }
        for i in 1...max(1, min(4, buildings.count)) {
            if let b = buildings[i].asPropList,
               let levels = b["LEVELS"].asList {
                for j in 1...max(1, levels.count) {
                    if let L = levels[j].asPropList,
                       let moves = L["moves"].asInt, moves > 0 {
                        keys += 1
                    }
                }
            }
        }
        if let rankdata = Glob.shared["rankdata"].asPropList {
            rankdata["keys"] = .int(keys)
        }
    }

    public func goldTotal() -> Int {
        var gotgold = 0
        guard let buildings = Glob.shared["building"].asList else { return 0 }
        for buildingIdx in 1...max(1, min(4, buildings.count)) {
            if let b = buildings[buildingIdx].asPropList,
               let levels = b["LEVELS"].asList {
                for levelIdx in 1...max(1, min(15, levels.count)) {
                    if let L = levels[levelIdx].asPropList {
                        let moves = L["moves"].asInt ?? 0
                        let goal = L["goal"].asInt ?? 0
                        if (moves > 0) && (goal >= moves) {
                            gotgold += 1
                            L["gold"] = .int(1)
                        }
                    }
                }
            }
        }
        return gotgold
    }

    public func updatePlaque() -> Int {
        let gotgold = goldTotal()
        if gotgold == 60 {
            Glob.shared["plaque"] = .string("president")
        } else if gotgold >= 40 {
            Glob.shared["plaque"] = .string("year")
        } else if gotgold >= 30 {
            Glob.shared["plaque"] = .string("Month")
        } else if gotgold >= 20 {
            Glob.shared["plaque"] = .string("week")
        } else if gotgold >= 10 {
            Glob.shared["plaque"] = .string("day")
        } else {
            Glob.shared["plaque"] = .string("welcome")
        }
        return gotgold
    }
}
