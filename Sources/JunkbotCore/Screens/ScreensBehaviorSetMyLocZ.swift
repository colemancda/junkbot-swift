// Translated from Lingo: behavior_set my locz.ls

class ScreensBehaviorSetMyLocZ: LingoObject, @unchecked Sendable {
    var mylocz: Int = 999999
    var spriteNum: Int = 0

    // Property description: mylocz is #integer, comment "LocZ:", default 999999

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   sprite(me.spriteNum).locZ = mylocz
    // end
    // ```
    func beginSprite() {
        sprite(spriteNum).locZ = mylocz
    }
}
