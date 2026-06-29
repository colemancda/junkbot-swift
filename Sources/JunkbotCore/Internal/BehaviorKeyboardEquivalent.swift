// Translated from Lingo: behavior_keyboard equivalent.ls

class BehaviorKeyboardEquivalent: BehaviorBase {
    var mykeys: String = ""
    var myMessage: String = "mouseUp"

    var spriteNum: Int = 0

    func equiv_keydown(_ k: String) {
        if mykeys.contains(k) {
            // sendSprite(spriteNum, myMessage)
        }
    }
}
