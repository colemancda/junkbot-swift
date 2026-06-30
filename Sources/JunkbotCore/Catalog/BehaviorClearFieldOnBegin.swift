// Translated from Lingo: behavior_clear field on begin.ls

class BehaviorClearFieldOnBegin: LingoObject, @unchecked Sendable {
    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   sprite(me.spriteNum).member.text = EMPTY
    // end
    // ```
    func beginSprite(_ spriteNum: Int) {
        sprite(spriteNum).member?.text = ""
    }
}
