// Translated from Lingo: behavior_HideRankBox.ls

class BehaviorHideRankBox {
    var spriteNum: Int = 0

    func beginSprite() {
        (Glob.shared["PLAYER"] as AnyObject).game_manager.TotalKeys()
        let rankdata = Glob.shared["rankdata"].asPropList!
        if (rankdata["keys"].asInt ?? 0) == (Glob.shared["hof"].asInt ?? 0) {
            sprite(spriteNum).loc = Point(x: 1000, y: 1000)
        } else {
            sprite(spriteNum).loc = Point(x: 487, y: 220)
        }
    }
}
