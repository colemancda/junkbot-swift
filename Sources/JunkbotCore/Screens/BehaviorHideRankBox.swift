// Translated from Lingo: behavior_HideRankBox.ls

class BehaviorHideRankBox {
    var spriteNum: Int = 0

    func beginSprite() {
        (glob["PLAYER"] as AnyObject).game_manager.TotalKeys()
        let rankdata = glob["rankdata"] as! [String: Any]
        if (rankdata["keys"] as! Int) == (glob["hof"] as! Int) {
            sprite(spriteNum).loc = Point(x: 1000, y: 1000)
        } else {
            sprite(spriteNum).loc = Point(x: 487, y: 220)
        }
    }
}
