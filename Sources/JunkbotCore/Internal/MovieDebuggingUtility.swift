// Translated from Lingo: movie_Debugging Utility Functions.ls

/// Returns the total count of levels where the player achieved gold
/// (completed the level in equal or fewer moves than the goal).
// Original Lingo body: goldtotal
// ```lingo
// on goldTotal
//   gotgold = 0
//   repeat with building = 1 to 4
//     repeat with level = 1 to 15
//       moves = glob[#building][building][#LEVELS][level][#moves]
//       goal = glob[#building][building][#LEVELS][level][#goal]
//       if (moves > 0) and (goal >= moves) then
//         gotgold = gotgold + 1
//       end if
//     end repeat
//   end repeat
//   return gotgold
// end
// ```
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
