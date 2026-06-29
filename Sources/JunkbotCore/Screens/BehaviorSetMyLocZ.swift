// Translated from Lingo: behavior_set my locz.ls

class BehaviorSetMyLocZ {
    var mylocz: Int = 999999
    var spriteNum: Int = 0

    // Property description: mylocz is #integer, comment "LocZ:", default 999999

    func beginSprite() {
        sprite(spriteNum).locZ = mylocz
    }
}
