// Translated from Lingo: behavior_ListRoHiLite.ls

class BehaviorListRoHiLite: LingoObject, @unchecked Sendable {
    var snum: Int = 0
    var roLineNum: Int = 0
    var spriteNum: Int = 0

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   snum = me.spriteNum - 1
    //   glob[#levelList] = me
    // end
    // ```
    func beginSprite() {
        snum = spriteNum - 1
        Glob.shared["levelList"] = .void  // set externally as object reference
    }

    // Original Lingo body: mousewithin
    // ```lingo
    // on mouseWithin me
    //   roLineNum = (the mouseV - 87) / 21
    //   if roLineNum > 14 then
    //     exit
    //   end if
    //   sprite(snum).locV = 87 + (roLineNum * 21)
    // end
    // ```
    func mouseWithin(mouseV: Int) {
        roLineNum = (mouseV - 87) / 21
        if roLineNum > 14 {
            return
        }
        sprite(snum).locV = 87 + (roLineNum * 21)
    }

    // Original Lingo body: mousedown
    // ```lingo
    // on mouseDown me
    //   roLineNum = (the mouseV - 87) / 21
    //   if (roLineNum > 14) or (roLineNum < 0) then
    //     exit
    //   end if
    //   glob.current.level = roLineNum + 1
    //   SndSFX("jump2")
    //   glob.PLAYER.game_manager.startGame()
    // end
    // ```
    func mouseDown(mouseV: Int) {
        roLineNum = (mouseV - 87) / 21
        if (roLineNum > 14) || (roLineNum < 0) {
            return
        }
        Glob.shared["current"]["level"] = .int(roLineNum + 1)
        SndSFX("jump2")
        (Glob.shared["PLAYER"]).game_manager.startGame()
    }
}
