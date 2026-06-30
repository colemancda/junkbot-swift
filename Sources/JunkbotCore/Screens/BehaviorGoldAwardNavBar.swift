// Translated from Lingo: behavior_Code for Gold Award info on Nav bar.ls

class BehaviorGoldAwardNavBar {
    var sp: LingoSprite? = nil
    var goal: Int = 0
    var moves: Int = 0
    var spriteNum: Int = 0

    func beginSprite() {
        Glob.shared["movenum"] = .void  // set externally as object reference
        sp = sprite(spriteNum)
        updateMovesNum()
    }

    func updateMovesNum() {
        let current = Glob.shared["current"].asPropList!
        let building = current["building"].asInt!
        let level = current["level"].asInt!
        let buildingList = Glob.shared["building"].asList!
        let buildingEntry = buildingList[building].asPropList!
        let levels = buildingEntry["LEVELS"].asList!
        let levelEntry = levels[level].asPropList!
        goal = levelEntry["goal"].asInt!
        moves = Int(member("play move counter field")?.text) ?? 0
        member("goal_amount_indicator")?.text = "\(goal) or fewer"
    }

    func exitFrame() {
        moves = Int(member("play move counter field")?.text) ?? 0
        if moves <= goal {
            sprite(spriteNum).blend = 100
        } else {
            sprite(spriteNum).blend = 0
        }
    }
}
