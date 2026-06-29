// Translated from Lingo: parent_game manager.ls

class GameManager {
    var gameState: String = "#PREGAME"
    var currentLevel: Any? = nil
    var currentLevelIndex: Int = 1
    var levelList: [Any]? = nil

    init() {
        gameState = "#PREGAME"
        prepareLevelMenu()
    }

    func prepareLevelMenu() {
        Glob.shared["building"] = [["state": "#open", "LEVELS": [Any]()]]
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
            var keys: Int? = nil // stub: externalParamValue("sw2")
            if keys == nil {
                keys = 10
            }
            Glob.shared["keyrequired"] = 10
            Glob.shared["current"] = ["building": 1, "level": 1, "moves": 0]
            level += 1
            if level > 15 {
                level = 1
                building += 1
                if var buildings = Glob.shared["building"] as? [[String: Any]] {
                    while buildings.count < building {
                        buildings.append([:])
                    }
                    buildings[building - 1] = ["state": "#locked", "LEVELS": [Any]()]
                    Glob.shared["building"] = buildings
                }
            }
            Glob.shared["plaque"] = "welcome"
        }
        Glob.shared["hof"] = 60
        if var rankdata = Glob.shared["rankdata"] as? [String: Any] {
            rankdata["serverState"] = "#network"
            Glob.shared["rankdata"] = rankdata
        }
        // let record = Glob.shared.database_manager.getRecord() -- stub
        let record: [String: Any]? = nil // stub
        if let record = record {
            decodeRecord(record)
        }
        totalKeys()
        if let rankdata = Glob.shared["rankdata"] as? [String: Any],
           let keys = rankdata["keys"] as? Int,
           let hof = Glob.shared["hof"] as? Int,
           keys >= hof {
            var rd = rankdata
            rd["AlreadySawHOF"] = "#YES"
            Glob.shared["rankdata"] = rd
        }
    }

    func encodeRecord() -> [String: Any] {
        var rec = [String: Any]()
        var state = 2
        var record = ""
        var total = 0
        guard let buildings = Glob.shared["building"] as? [[String: Any]] else { return rec }
        guard let current = Glob.shared["current"] as? [String: Any] else { return rec }
        let currentBuilding = current["building"] as? Int ?? 0
        let currentLevelIdx = current["level"] as? Int ?? 0
        let currentMoves = current["moves"] as? Int ?? 0
        for (bn, b) in buildings.enumerated() {
            let bnIdx = bn + 1
            guard let levels = b["LEVELS"] as? [[String: Any]] else { continue }
            for (ln, L) in levels.enumerated() {
                let lnIdx = ln + 1
                var m: Any
                if (bnIdx == currentBuilding) && (lnIdx == currentLevelIdx) {
                    m = currentMoves
                } else {
                    m = L["moves"] as? Int ?? 0
                }
                let mInt = m as? Int ?? 0
                if mInt == 0 {
                    state = 0
                    continue
                }
                total += mInt
                let goal = L["goal"] as? Int ?? 0
                if (state > 0) && (mInt > goal) {
                    state = 1
                }
                let mStr: String
                if mInt > 999 {
                    mStr = "+"
                } else {
                    mStr = String(mInt)
                }
                let index = L["index"] as? Int ?? 0
                record += "\(index) \(mStr),"
            }
        }
        // delete char -30000 of record — remove trailing comma
        if record.hasSuffix(",") {
            record.removeLast()
        }
        rec["state"] = state
        rec["total"] = total
        rec["record"] = record
        totalKeys()
        if var rankdata = Glob.shared["rankdata"] as? [String: Any] {
            rankdata["moves"] = total
            Glob.shared["rankdata"] = rankdata
        }
        return rec
    }

    func decodeRecord(_ rec: [String: Any]) {
        guard let recordStr = rec["record"] as? String else { return }
        let items = recordStr.components(separatedBy: ",")
        for entry in items {
            let words = entry.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").filter { !$0.isEmpty }
            guard words.count >= 2,
                  let n = Int(words[0]),
                  let m = Int(words[1]) else { continue }
            let building = (n - 1) / 15 + 1
            let level = n - (15 * (building - 1))
            if var buildings = Glob.shared["building"] as? [[String: Any]],
               buildings.count >= building {
                if var levels = buildings[building - 1]["LEVELS"] as? [[String: Any]],
                   levels.count >= level {
                    levels[level - 1]["moves"] = m
                    buildings[building - 1]["LEVELS"] = levels
                    Glob.shared["building"] = buildings
                }
            }
        }
        if var rankdata = Glob.shared["rankdata"] as? [String: Any] {
            rankdata["moves"] = rec["total"]
            Glob.shared["rankdata"] = rankdata
        }
    }

    func setGame(_ L: [Any]) {
        levelList = L
        currentLevelIndex = 1
    }

    func selectlevel() {
        exitGame()
        go("levels") // stub
    }

    func startGame() {
        go("play") // stub
        startLevel()
    }

    func restartLevel() {
        // Glob.shared.PLAYER.play_manager.leave()
        // Glob.shared.PLAYER.play_manager.setLevel(currentLevel)
        // Glob.shared.PLAYER.play_manager.startLevel()
    }

    func pauseLevel(_ flag: Bool) {
        if gameState == "#INLEVEL" {
            // Glob.shared.PLAYER.play_manager.pauseLevel(flag)
        }
    }

    func exitGame() {
        // Glob.shared.PLAYER.play_manager.leave()
        SndMusicEnd() // stub
    }

    func gameOverButton() {
        // Glob.shared.PLAYER.play_manager.leave()
        gameState = "#PREGAME"
        SndMusicEnd() // stub
        // Glob.shared.download_manager.mainmenu()
    }

    func callback(_ p: String) {
        switch p {
        case "#com_nextlevel":
            if var current = Glob.shared["current"] as? [String: Any],
               let lv = current["level"] as? Int {
                current["level"] = lv + 1
                Glob.shared["current"] = current
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

    func endLevel(_ winOrLose: String) {
        SndMusicEnd() // stub
        setCursor("#none") // stub
        if winOrLose == "#WIN" {
            if var current = Glob.shared["current"] as? [String: Any] {
                // current["moves"] = Glob.shared.PLAYER.play_manager.gamestatus.moves
                Glob.shared["current"] = current
            }
            SndSFX("voice_ohyeah") // stub
            intermission()
            // Glob.shared.database_manager.setRecord(encodeRecord())
        } else {
            loseGame()
        }
    }

    func startLevel() {
        // Glob.shared.PLAYER.play_manager.leave()
        SndMusicStart("level\(Int.random(in: 1...5))") // stub
        if levelList == nil {
            guard let current = Glob.shared["current"] as? [String: Any],
                  let buildingIdx = current["building"] as? Int,
                  let levelIdx = current["level"] as? Int,
                  let buildings = Glob.shared["building"] as? [[String: Any]],
                  buildings.count >= buildingIdx,
                  let levels = buildings[buildingIdx - 1]["LEVELS"] as? [[String: Any]] else { return }
            if levelIdx > levels.count {
                selectlevel()
            } else {
                let lvl = levels[levelIdx - 1]
                currentLevel = lvl["data"]
                // Glob.shared.PLAYER.play_manager.setLevel(currentLevel)
                // Glob.shared.title_obj.updateData([buildingIdx, levelIdx, lvl["title"]], ["object": self, "parameter": "#title_done"])
            }
        } else if let list = levelList {
            currentLevel = list[currentLevelIndex - 1]
            // Glob.shared.PLAYER.play_manager.setLevel(currentLevel)
            // Glob.shared.PLAYER.play_manager.startLevel()
        }
    }

    func loseGame() {
        SndMusicEnd() // stub
        gameState = "#loseGame"
        // Glob.shared.fail_msg_obj.updateData()
    }

    func finishGame() {
        SndMusicEnd() // stub
        gameState = "#finishGame"
        // Glob.shared.PLAYER["signsprite"].showSign("signGameFinish", "#gameOverButton")
    }

    func intermission() {
        gameState = "#INTERLEVEL"
        // Glob.shared["master_obj"].dropBox()
    }

    func totalKeys() {
        var keys = 0
        guard let buildings = Glob.shared["building"] as? [[String: Any]] else { return }
        for i in 0..<min(4, buildings.count) {
            if let levels = buildings[i]["LEVELS"] as? [[String: Any]] {
                for j in 0..<levels.count {
                    if let moves = levels[j]["moves"] as? Int, moves > 0 {
                        keys += 1
                    }
                }
            }
        }
        if var rankdata = Glob.shared["rankdata"] as? [String: Any] {
            rankdata["keys"] = keys
            Glob.shared["rankdata"] = rankdata
        }
    }

    func goldTotal() -> Int {
        var gotgold = 0
        guard let buildings = Glob.shared["building"] as? [[String: Any]] else { return 0 }
        for buildingIdx in 0..<min(4, buildings.count) {
            if var levels = buildings[buildingIdx]["LEVELS"] as? [[String: Any]] {
                for levelIdx in 0..<min(15, levels.count) {
                    let moves = levels[levelIdx]["moves"] as? Int ?? 0
                    let goal = levels[levelIdx]["goal"] as? Int ?? 0
                    if (moves > 0) && (goal >= moves) {
                        gotgold += 1
                        levels[levelIdx]["gold"] = 1
                        var b = buildings[buildingIdx]
                        b["LEVELS"] = levels
                        var mutableBuildings = buildings
                        mutableBuildings[buildingIdx] = b
                        Glob.shared["building"] = mutableBuildings
                    }
                }
            }
        }
        return gotgold
    }

    func updatePlaque() -> Int {
        let gotgold = goldTotal()
        if gotgold == 60 {
            Glob.shared["plaque"] = "president"
        } else if gotgold >= 40 {
            Glob.shared["plaque"] = "year"
        } else if gotgold >= 30 {
            Glob.shared["plaque"] = "Month"
        } else if gotgold >= 20 {
            Glob.shared["plaque"] = "week"
        } else if gotgold >= 10 {
            Glob.shared["plaque"] = "day"
        } else {
            Glob.shared["plaque"] = "welcome"
        }
        return gotgold
    }
}

// Stubs for Director-specific global functions
func go(_ scene: String) { /* stub */ }
func setCursor(_ cursor: String) { /* stub */ }
func SndSFX(_ name: String) { /* stub */ }
func SndSFX(_ name: String, _ arg1: Any?, _ arg2: Int) { /* stub */ }
func SndMusicStart(_ name: String) { /* stub */ }
func SndMusicEnd() { /* stub */ }
