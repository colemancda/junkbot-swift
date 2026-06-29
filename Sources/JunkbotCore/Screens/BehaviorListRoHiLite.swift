// Translated from Lingo: behavior_ListRoHiLite.ls

class BehaviorListRoHiLite {
    var snum: Int = 0
    var roLineNum: Int = 0
    var spriteNum: Int = 0

    func beginSprite() {
        snum = spriteNum - 1
        Glob.shared["levelList"] = .void  // set externally as object reference
    }

    func mouseWithin(mouseV: Int) {
        roLineNum = (mouseV - 87) / 21
        if roLineNum > 14 {
            return
        }
        sprite(snum).locV = 87 + (roLineNum * 21)
    }

    func mouseDown(mouseV: Int) {
        roLineNum = (mouseV - 87) / 21
        if (roLineNum > 14) || (roLineNum < 0) {
            return
        }
        Glob.shared["current"].asPropList!["level"] = .int(roLineNum + 1)
        SndSFX("jump2")
        (Glob.shared["PLAYER"] as AnyObject).game_manager.startGame()
    }
}
