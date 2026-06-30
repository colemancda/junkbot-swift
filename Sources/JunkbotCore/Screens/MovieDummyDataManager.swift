// Translated from Lingo: movie_dummy_data_manager.ls

struct MovieDummyDataManager {
    // Original Lingo body: initdummy
    // ```lingo
    // on initDummy
    //   glob[#keyrequired] = 2
    //   glob[#current] = [#building: 1, #level: 1, #moves: 30]
    //   glob[#building] = []
    //   repeat with i = 1 to 4
    //     temp = []
    //     repeat with j = 1 to 15
    //       temp.add([#title: "Dummy TITLE HAHA", #goal: 20, #moves: 0])
    //     end repeat
    //     state = #locked
    //     if i = 1 then
    //       state = #open
    //     end if
    //     glob[#building].add([#state: state, #LEVELS: temp])
    //   end repeat
    // end
    // ```
    static func initDummy() {
        Glob.shared["keyrequired"] = .int(2)
        var current = PropList()
        current["building"] = .int(1)
        current["level"] = .int(1)
        current["moves"] = .int(30)
        Glob.shared["current"] = .propList(current)
        let buildings = LingoList()
        for i in 1...4 {
            let levels = LingoList()
            for _ in 1...15 {
                var lvl = PropList()
                lvl["title"] = .string("Dummy TITLE HAHA")
                lvl["goal"] = .int(20)
                lvl["moves"] = .int(0)
                levels.add(.propList(lvl))
            }
            let state: String = (i == 1) ? "open" : "locked"
            var building = PropList()
            building["state"] = .string(state)
            building["LEVELS"] = .list(levels)
            buildings.add(.propList(building))
        }
        Glob.shared["building"] = .list(buildings)
    }

    // Original Lingo body: updatedummydata
    // ```lingo
    // on updateDummyData data
    //   tempLevel = glob[#building][data[1]][#LEVELS][data[2]]
    //   if not voidp(data[#title]) then
    //     tempLevel[#title] = data[#title]
    //   end if
    //   if not voidp(data[#goal]) then
    //     tempLevel[#goal] = data[#goal]
    //   end if
    //   if not voidp(data[#moves]) then
    //     tempLevel[#moves] = data[#moves]
    //   end if
    // end
    // ```
    static func updateDummyData(_ data: PropList) {
        let buildings = Glob.shared["building"].asList!
        let buildingIdx = data["building"].asInt!
        let levelIdx = data["level"].asInt!
        let buildingEntry = buildings[buildingIdx].asPropList!
        let levels = buildingEntry["LEVELS"].asList!
        let tempLevel = levels[levelIdx].asPropList!
        if let title = data["title"].asString {
            tempLevel["title"] = .string(title)
        }
        if let goal = data["goal"].asInt {
            tempLevel["goal"] = .int(goal)
        }
        if let moves = data["moves"].asInt {
            tempLevel["moves"] = .int(moves)
        }
    }

    // Original Lingo body: updatebuilding
    // ```lingo
    // on updateBuilding data
    //   glob[#building][data[1]][#state] = data[2]
    // end
    // ```
    static func updateBuilding(_ data: LingoList) {
        let buildings = Glob.shared["building"].asList!
        let idx = data[1].asInt!
        buildings[idx]["state"] = data[2]
    }
}
