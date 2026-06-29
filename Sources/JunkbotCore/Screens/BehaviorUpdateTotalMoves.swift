// Translated from Lingo: behavior_UpdateTotalMoves.ls

class BehaviorUpdateTotalMoves {
    var spriteNum: Int = 0

    func beginSprite() {
        let rankdata = glob["rankdata"] as! [String: Any]
        if (rankdata["keys"] as! Int) < (glob["hof"] as! Int) {
            return
        }
        sprite(spriteNum).member.text = String((glob["rankdata"] as! [String: Any])["moves"] as! Int)
    }
}
