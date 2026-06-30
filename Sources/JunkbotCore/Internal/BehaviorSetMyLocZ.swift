// Translated from Lingo: behavior_set my locz.ls

class BehaviorSetMyLocZ: LingoObject, @unchecked Sendable {
  var mylocz: Int = 999999

  var spriteNum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   sprite(me.spriteNum).locZ = mylocz
  // end
  // ```
  func beginSprite() {
    // sprite(spriteNum).locZ = mylocz
  }
}
