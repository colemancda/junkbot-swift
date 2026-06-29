// Translated from Lingo: behavior_UpdateTotalMoves.ls

class BehaviorUpdateTotalMoves {
    var spriteNum: Int = 0

    func beginSprite() {
        let rankdata = Glob.shared["rankdata"].asPropList!
        if (rankdata["keys"].asInt ?? 0) < (Glob.shared["hof"].asInt ?? 0) {
            return
        }
        sprite(spriteNum).member.text = String(Glob.shared["rankdata"].asPropList!["moves"].asInt!)
    }
}
