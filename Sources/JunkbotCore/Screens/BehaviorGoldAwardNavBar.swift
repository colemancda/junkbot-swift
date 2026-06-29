// Translated from Lingo: behavior_Code for Gold Award info on Nav bar.ls

class BehaviorGoldAwardNavBar {
    var sp: Any? = nil
    var goal: Int = 0
    var moves: Int = 0
    var spriteNum: Int = 0

    func beginSprite() {
        glob["movenum"] = self
        sp = sprite(spriteNum)
        updateMovesNum()
    }

    func updateMovesNum() {
        let building = (glob["current"] as! [String: Any])["building"] as! Int
        let level = (glob["current"] as! [String: Any])["level"] as! Int
        goal = ((glob["building"] as! [[String: Any]])[building - 1]["LEVELS"] as! [[String: Any]])[level - 1]["goal"] as! Int
        moves = Int(member("play move counter field").text) ?? 0
        member("goal_amount_indicator").text = "\(goal) or fewer"
    }

    func exitFrame() {
        moves = Int(member("play move counter field").text) ?? 0
        if moves <= goal {
            sprite(spriteNum).blend = 100
        } else {
            sprite(spriteNum).blend = 0
        }
    }
}
