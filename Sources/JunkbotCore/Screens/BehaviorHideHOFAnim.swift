// Translated from Lingo: behavior_hide_HOF_anim.ls

class BehaviorHideHOFAnim: LingoObject, @unchecked Sendable {
    var spriteNum: Int = 0

    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   sprite(me.spriteNum).loc = point(1000, 1000)
    // end
    // ```
    func mouseUp() {
        sprite(spriteNum).loc = Point(x: 1000, y: 1000)
    }
}
