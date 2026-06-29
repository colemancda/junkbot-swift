// Translated from Lingo: movie_dummy_data_manager.ls

struct MovieDummyDataManager {
    static func initDummy() {
        glob["keyrequired"] = 2
        glob["current"] = ["building": 1, "level": 1, "moves": 30] as [String: Any]
        var buildings = [Any]()
        for i in 1...4 {
            var temp = [Any]()
            for _ in 1...15 {
                temp.append(["title": "Dummy TITLE HAHA", "goal": 20, "moves": 0] as [String: Any])
            }
            let state: String = (i == 1) ? "open" : "locked"
            buildings.append(["state": state, "LEVELS": temp] as [String: Any])
        }
        glob["building"] = buildings
    }

    static func updateDummyData(_ data: [AnyHashable: Any]) {
        var buildings = glob["building"] as! [[String: Any]]
        let buildingIdx = (data[1] as! Int) - 1
        let levelIdx = (data[2] as! Int) - 1
        var tempLevel = (buildings[buildingIdx]["LEVELS"] as! [[String: Any]])[levelIdx]
        if let title = data["title"] as? String {
            tempLevel["title"] = title
        }
        if let goal = data["goal"] as? Int {
            tempLevel["goal"] = goal
        }
        if let moves = data["moves"] as? Int {
            tempLevel["moves"] = moves
        }
        var levels = buildings[buildingIdx]["LEVELS"] as! [[String: Any]]
        levels[levelIdx] = tempLevel
        buildings[buildingIdx]["LEVELS"] = levels
        glob["building"] = buildings
    }

    static func updateBuilding(_ data: [Any]) {
        var buildings = glob["building"] as! [[String: Any]]
        let idx = (data[0] as! Int) - 1
        buildings[idx]["state"] = data[1] as! String
        glob["building"] = buildings
    }
}
