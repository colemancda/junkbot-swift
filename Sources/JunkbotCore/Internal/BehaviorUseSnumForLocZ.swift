// Translated from Lingo: behavior_useSnumForLocZ.ls

class BehaviorUseSnumForLocZ: LingoObject, @unchecked Sendable {
  var spriteNum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   sprite(me.spriteNum).locZ = me.spriteNum
  // end
  // ```
  func beginSprite() {
    // sprite(spriteNum).locZ = spriteNum
  }
}
