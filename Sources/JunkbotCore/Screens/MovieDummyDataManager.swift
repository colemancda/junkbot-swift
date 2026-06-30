// Translated from Lingo: movie_dummy_data_manager.ls

struct MovieDummyDataManager {
    static func initDummy() {
        Glob.shared["keyrequired"] = .int(2)
        let current = PropList()
        current["building"] = .int(1)
        current["level"] = .int(1)
        current["moves"] = .int(30)
        Glob.shared["current"] = .propList(current)
        let buildings = LingoList()
        for i in 1...4 {
            let levels = LingoList()
            for _ in 1...15 {
                let lvl = PropList()
                lvl["title"] = .string("Dummy TITLE HAHA")
                lvl["goal"] = .int(20)
                lvl["moves"] = .int(0)
                levels.add(.propList(lvl))
            }
            let state: String = (i == 1) ? "open" : "locked"
            let building = PropList()
            building["state"] = .string(state)
            building["LEVELS"] = .list(levels)
            buildings.add(.propList(building))
        }
        Glob.shared["building"] = .list(buildings)
    }

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

    static func updateBuilding(_ data: LingoList) {
        let buildings = Glob.shared["building"].asList!
        let idx = data[1].asInt!
        buildings[idx]["state"] = data[2]
    }
}
