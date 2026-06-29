// Translated from Lingo: movie_Debugging Utility Functions.ls

import Foundation

/// Returns the total count of levels where the player achieved gold
/// (completed the level in equal or fewer moves than the goal).
func goldTotal(glob: [String: Any]) -> Int {
    var gotgold = 0
    for building in 1...4 {
        for level in 1...15 {
            let buildingData = ((glob["building"] as? [String: Any])?["\(building)"] as? [String: Any])
            let levelData = ((buildingData?["LEVELS"] as? [String: Any])?["\(level)"] as? [String: Any])
            let moves = (levelData?["moves"] as? Int) ?? 0
            let goal = (levelData?["goal"] as? Int) ?? 0
            if moves > 0 && goal >= moves {
                gotgold += 1
            }
        }
    }
    return gotgold
}
