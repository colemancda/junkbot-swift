// Translated from Lingo: behavior_hide_HOF_anim.ls

class BehaviorHideHOFAnim {
    var spriteNum: Int = 0

    func mouseUp() {
        sprite(spriteNum).loc = Point(x: 1000, y: 1000)
    }
}
