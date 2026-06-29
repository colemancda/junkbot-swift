// Translated from Lingo: behavior_self-update_portrait.ls

class BehaviorSelfUpdatePortrait {
    var spriteNum: Int = 0

    func beginSprite() {
        let rankdata = glob["rankdata"] as! [String: Any]
        let hof = glob["hof"] as! Int
        if (rankdata["keys"] as! Int) < hof {
            sprite(spriteNum).member = member("portrait_1")
            sprite(spriteNum).width = 148
            sprite(spriteNum).height = 130
            sprite(spriteNum).loc = Point(x: 566, y: 88)
        } else {
            sprite(spriteNum).member = member("portrait_2")
            sprite(spriteNum).width = 135
            sprite(spriteNum).height = 120
            sprite(spriteNum).loc = Point(x: 560, y: 83)
        }
    }
}
