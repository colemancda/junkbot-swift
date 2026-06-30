// Translated from Lingo: behavior_Code for Gold Award info on Nav bar.ls

class BehaviorGoldAwardNavBar: LingoObject, @unchecked Sendable {
  var sp: LingoSprite? = nil
  var goal: Int = 0
  var moves: Int = 0
  var spriteNum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   glob[#movenum] = me
  //   sp = sprite(me.spriteNum)
  //   updateMovesNum(me)
  // end
  // ```
  func beginSprite() {
    Glob.shared["movenum"] = .void  // set externally as object reference
    sp = sprite(spriteNum)
    updateMovesNum()
  }

  // Original Lingo body: updatemovesnum
  // ```lingo
  // on updateMovesNum me
  //   building = glob[#current][#building]
  //   level = glob[#current][#level]
  //   goal = glob[#building][building][#LEVELS][level][#goal]
  //   moves = integer(member("play move counter field").text)
  //   member("goal_amount_indicator").text = string(goal) & " or fewer"
  // end
  // ```
  func updateMovesNum() {
    let current = Glob.shared["current"].asPropList!
    let building = current["building"].asInt!
    let level = current["level"].asInt!
    let buildingList = Glob.shared["building"].asList!
    let buildingEntry = buildingList[building].asPropList!
    let levels = buildingEntry["LEVELS"].asList!
    let levelEntry = levels[level].asPropList!
    goal = levelEntry["goal"].asInt!
    moves = Int(member("play move counter field")?.text ?? "") ?? 0
    member("goal_amount_indicator")?.text = "\(goal) or fewer"
  }

  // Original Lingo body: exitframe
  // ```lingo
  // on exitFrame me
  //   moves = integer(member("play move counter field").text)
  //   if moves <= goal then
  //     sp.blend = 100
  //   else
  //     sp.blend = 0
  //   end if
  // end
  // ```
  func exitFrame() {
    moves = Int(member("play move counter field")?.text ?? "") ?? 0
    if moves <= goal {
      sprite(spriteNum).blend = 100
    } else {
      sprite(spriteNum).blend = 0
    }
  }
}
