// Translated from Lingo: behavior_self-update_portrait.ls

class BehaviorSelfUpdatePortrait {
    var spriteNum: Int = 0

    func beginSprite() {
        let rankdata = Glob.shared["rankdata"].asPropList!
        let hof = Glob.shared["hof"].asInt!
        if (rankdata["keys"].asInt ?? 0) < hof {
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
