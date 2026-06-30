// Translated from Lingo: parent_game manager.ls

public class GameManager: LingoObject, @unchecked Sendable {
    public var gameState: String = "#PREGAME"
    public var currentLevel: LV = .void
    public var currentLevelIndex: Int = 1
    public var levelList: LingoList? = nil

    // Original Lingo body: new
    // ```lingo
    // on new me
    //   gameState = #PREGAME
    //   me.prepareLevelMenu()
    //   return me
    // end
    // ```
    public override init() {
        super.init()
        gameState = "#PREGAME"
        prepareLevelMenu()
    }

    // Original Lingo body: preparelevelmenu
    // ```lingo
    // on prepareLevelMenu me
    //   glob[#building] = [[#state: #open, #LEVELS: []]]
    //   building = 1
    //   level = 1
    //   repeat with n = 1 to the number of castMembers of castLib "levels"
    //     levelmem = member(n, "levels")
    //     leveldata = glob.config_manager.parseParams(levelmem.text)
    //     leveldata.info.title = glob.config_manager.restoreCommas(leveldata.info.title)
    //     leveldata.info.hint = glob.config_manager.restoreCommas(leveldata.info.hint)
    //     glob.building[building].LEVELS[level] = [#index: n, #title: leveldata.info.title, #goal: leveldata.info.par, #moves: 0, #data: levelmem.text, #info: leveldata.info]
    //     keys = integer(externalParamValue("sw2"))
    //     if voidp(keys) then
    //       keys = 10
    //     end if
    //     glob[#keyrequired] = 10
    //     glob[#current] = [#building: 1, #level: 1, #moves: 0]
    //     level = level + 1
    //     if level > 15 then
    //       level = 1
    //       building = building + 1
    //       glob.building[building] = [#state: #locked, #LEVELS: []]
    //     end if
    //     glob[#plaque] = "welcome"
    //   end repeat
    //   glob[#hof] = 60
    //   glob[#rankdata][#serverState] = #network
    //   record = glob.database_manager.getRecord()
    //   if not voidp(record) then
    //     me.decodeRecord(record)
    //   end if
    //   me.TotalKeys()
    //   if glob.rankdata.keys >= glob.hof then
    //     glob.rankdata[#AlreadySawHOF] = #YES
    //   end if
    // end
    // ```
    public func prepareLevelMenu() {
        var firstBuilding = PropList()
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
            var current = PropList()
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
                        var b = PropList()
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

    // Original Lingo body: encoderecord
    // ```lingo
    // on encodeREcord me
    //   rec = [:]
    //   state = 2
    //   record = EMPTY
    //   total = 0
    //   repeat with bn = 1 to glob.building.count
    //     b = glob.building[bn]
    //     repeat with ln = 1 to b.LEVELS.count
    //       L = b.LEVELS[ln]
    //       if (bn = glob.current.building) and (ln = glob.current.level) then
    //         m = glob.current.moves
    //       else
    //         m = L.moves
    //       end if
    //       if m = 0 then
    //         state = 0
    //         next repeat
    //       end if
    //       total = total + m
    //       if (state > 0) and (m > L.goal) then
    //         state = 1
    //       end if
    //       if m > 999 then
    //         m = "+"
    //       end if
    //       record = record & L.index & " " & m & ","
    //     end repeat
    //   end repeat
    //   delete char -30000 of record
    //   rec[#state] = state
    //   rec[#total] = total
    //   rec[#record] = record
    //   me.TotalKeys()
    //   glob.rankdata[#moves] = total
    //   return rec
    // end
    // ```
    public func encodeRecord() -> PropList {
        var rec = PropList()
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

    // Original Lingo body: decoderecord
    // ```lingo
    // on decodeRecord me, rec
    //   repeat with i = 1 to rec.record.item.count
    //     Entry = item i of the record of rec
    //     n = integer(word 1 of Entry)
    //     m = integer(word 2 of Entry)
    //     if voidp(n) or voidp(m) then
    //       next repeat
    //     end if
    //     building = integer((n - 1) / 15) + 1
    //     level = n - (15 * (building - 1))
    //     glob.building[building].LEVELS[level].moves = m
    //   end repeat
    //   glob.rankdata[#moves] = rec.total
    // end
    // ```
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

    // Original Lingo body: setgame
    // ```lingo
    // on setGame me, L
    //   levelList = L
    //   currentLevelIndex = 1
    // end
    // ```
    public func setGame(_ L: LingoList) {
        levelList = L
        currentLevelIndex = 1
    }

    // Original Lingo body: selectlevel
    // ```lingo
    // on selectlevel me
    //   me.exitGame()
    //   go("levels")
    // end
    // ```
    public func selectlevel() {
        exitGame()
        go("levels")
    }

    // Original Lingo body: startgame
    // ```lingo
    // on startGame me
    //   go("play")
    //   me.startLevel()
    // end
    // ```
    public func startGame() {
        go("play")
        startLevel()
    }

    // Original Lingo body: restartlevel
    // ```lingo
    // on restartLevel me
    //   glob.PLAYER.play_manager.leave()
    //   glob.PLAYER.play_manager.setLevel(currentLevel)
    //   glob.PLAYER.play_manager.startLevel()
    // end
    // ```
    public func restartLevel() {
        // Glob.shared.PLAYER.play_manager.leave()
        // Glob.shared.PLAYER.play_manager.setLevel(currentLevel)
        // Glob.shared.PLAYER.play_manager.startLevel()
    }

    // Original Lingo body: pauselevel
    // ```lingo
    // on pauseLevel me, flag
    //   if gameState = #INLEVEL then
    //     glob.PLAYER.play_manager.pauseLevel(flag)
    //   end if
    // end
    // ```
    public func pauseLevel(_ flag: Bool) {
        if gameState == "#INLEVEL" {
            // Glob.shared.PLAYER.play_manager.pauseLevel(flag)
        }
    }

    // Original Lingo body: exitgame
    // ```lingo
    // on exitGame me
    //   glob.PLAYER.play_manager.leave()
    //   SndMusicEnd()
    // end
    // ```
    public func exitGame() {
        // Glob.shared.PLAYER.play_manager.leave()
        SndMusicEnd()
    }

    // Original Lingo body: gameoverbutton
    // ```lingo
    // on gameOverButton me
    //   glob.PLAYER.play_manager.leave()
    //   gameState = #PREGAME
    //   SndMusicEnd()
    //   glob.download_manager.mainmenu()
    // end
    // ```
    public func gameOverButton() {
        // Glob.shared.PLAYER.play_manager.leave()
        gameState = "#PREGAME"
        SndMusicEnd()
        // Glob.shared.download_manager.mainmenu()
    }

    // Original Lingo body: callback
    // ```lingo
    // on callback me, p
    //   case p of
    //     #com_nextlevel:
    //       glob.current.level = glob.current.level + 1
    //       me.startLevel()
    //     #title_done:
    //       glob.PLAYER.play_manager.startLevel()
    //     #restart_level:
    //       me.startGame()
    //     #select_level:
    //       me.selectlevel()
    //   end case
    // end
    // ```
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

    // Original Lingo body: endlevel
    // ```lingo
    // on endLevel me, winOrLose
    //   SndMusicEnd()
    //   setCursor(#none)
    //   if winOrLose = #WIN then
    //     glob.current.moves = glob.PLAYER.play_manager.gamestatus.moves
    //     SndSFX("voice_ohyeah")
    //     me.intermission()
    //     glob.database_manager.setRecord(me.encodeREcord())
    //   else
    //     me.loseGame()
    //   end if
    // end
    // ```
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

    // Original Lingo body: startlevel
    // ```lingo
    // on startLevel me
    //   glob.PLAYER.play_manager.leave()
    //   SndMusicStart("level" & random(5))
    //   if voidp(levelList) then
    //     if glob.current.level > glob.building[glob.current.building].LEVELS.count then
    //       me.selectlevel()
    //     else
    //       currentLevel = glob.building[glob.current.building].LEVELS[glob.current.level].data
    //       glob.PLAYER.play_manager.setLevel(currentLevel)
    //       glob.title_obj.updateData([glob.current.building, glob.current.level, glob.building[glob.current.building].LEVELS[glob.current.level].title], [#object: me, #parameter: #title_done])
    //     end if
    //   else
    //     currentLevel = levelList[currentLevelIndex]
    //     glob.PLAYER.play_manager.setLevel(currentLevel)
    //     glob.PLAYER.play_manager.startLevel()
    //   end if
    // end
    // ```
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

    // Original Lingo body: losegame
    // ```lingo
    // on loseGame me
    //   SndMusicEnd()
    //   gameState = #loseGame
    //   glob.fail_msg_obj.updateData()
    // end
    // ```
    public func loseGame() {
        SndMusicEnd()
        gameState = "#loseGame"
        // Glob.shared.fail_msg_obj.updateData()
    }

    // Original Lingo body: finishgame
    // ```lingo
    // on finishGame me
    //   SndMusicEnd()
    //   gameState = #finishGame
    //   glob.PLAYER[#signsprite].showSign("signGameFinish", #gameOverButton)
    // end
    // ```
    public func finishGame() {
        SndMusicEnd()
        gameState = "#finishGame"
        // Glob.shared.PLAYER["signsprite"].showSign("signGameFinish", "#gameOverButton")
    }

    // Original Lingo body: intermission
    // ```lingo
    // on intermission me
    //   gameState = #INTERLEVEL
    //   glob[#master_obj].dropBox()
    // end
    // ```
    public func intermission() {
        gameState = "#INTERLEVEL"
        // Glob.shared["master_obj"].dropBox()
    }

    // Original Lingo body: totalkeys
    // ```lingo
    // on TotalKeys me
    //   keys = 0
    //   repeat with i = 1 to 4
    //     building = glob[#building][i][#LEVELS]
    //     repeat with j = 1 to building.count
    //       if building[j][#moves] > 0 then
    //         keys = keys + 1
    //       end if
    //     end repeat
    //   end repeat
    //   glob[#rankdata][#keys] = keys
    // end
    // ```
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

    // Original Lingo body: goldtotal
    // ```lingo
    // on goldTotal me
    //   gotgold = 0
    //   repeat with building = 1 to 4
    //     repeat with level = 1 to 15
    //       moves = glob[#building][building][#LEVELS][level][#moves]
    //       goal = glob[#building][building][#LEVELS][level][#goal]
    //       if (moves > 0) and (goal >= moves) then
    //         gotgold = gotgold + 1
    //         glob[#building][building][#LEVELS][level][#gold] = 1
    //       end if
    //     end repeat
    //   end repeat
    //   return gotgold
    // end
    // ```
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

    // Original Lingo body: updateplaque
    // ```lingo
    // on updatePlaque me
    //   gotgold = me.goldTotal()
    //   if gotgold = 60 then
    //     glob[#plaque] = "president"
    //   else
    //     if gotgold >= 40 then
    //       glob[#plaque] = "year"
    //     else
    //       if gotgold >= 30 then
    //         glob[#plaque] = "Month"
    //       else
    //         if gotgold >= 20 then
    //           glob[#plaque] = "week"
    //         else
    //           if gotgold >= 10 then
    //             glob[#plaque] = "day"
    //           else
    //             glob[#plaque] = "welcome"
    //           end if
    //         end if
    //       end if
    //     end if
    //   end if
    //   return gotgold
    // end
    // ```
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
