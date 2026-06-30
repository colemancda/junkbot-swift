// Translated from Lingo: behavior_keyboard equivalent.ls

class BehaviorKeyboardEquivalent: LingoObject, @unchecked Sendable {
  var mykeys: String = ""
  var myMessage: String = "mouseUp"

  var spriteNum: Int = 0

  // Original Lingo body: equiv_keydown
  // ```lingo
  // on equiv_keydown me, k
  //   if mykeys contains k then
  //     sendSprite(me.spriteNum, myMessage)
  //   end if
  // end
  // ```
  func equiv_keydown(_ k: String) {
    if mykeys.contains(k) {
      // sendSprite(spriteNum, myMessage)
    }
  }
}
