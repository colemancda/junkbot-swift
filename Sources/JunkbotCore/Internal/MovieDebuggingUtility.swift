// Translated from Lingo: movie_Debugging Utility Functions.ls

/// Returns the total count of levels where the player achieved gold
/// (completed the level in equal or fewer moves than the goal).
func goldTotal() -> Int {
    let glob = Glob.shared
    var gotgold = 0
    for building in 1...4 {
        for level in 1...15 {
            let buildingData = glob["\(building)"].asPropList
            let levelData = buildingData?["LEVELS"].asPropList?["\(level)"].asPropList
            let moves = levelData?["moves"].asInt ?? 0
            let goal = levelData?["goal"].asInt ?? 0
            if moves > 0 && goal >= moves {
                gotgold += 1
            }
        }
    }
    return gotgold
}
