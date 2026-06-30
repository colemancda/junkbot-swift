// Translated from Lingo: behavior_plaque_self_control_code.ls

class BehaviorPlaqueSelfControl: LingoObject, @unchecked Sendable {
    var snum: Int = 0
    var myPlaque: String = ""

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   snum = me.spriteNum
    //   myPlaque = glob[#plaque]
    //   glob.PLAYER[#game_manager].updatePlaque()
    //   sprite(snum).member = member("plaque_" & glob[#plaque])
    // end
    // ```
    func beginSprite() {
        myPlaque = Glob.shared["plaque"].asString!
        (Glob.shared["PLAYER"]).game_manager.updatePlaque()
        sprite(snum).member = member("plaque_\(Glob.shared["plaque"].asString!)")
    }

    // Original Lingo body: exitframe
    // ```lingo
    // on exitFrame me
    //   if not (myPlaque = glob[#plaque]) then
    //     myPlaque = glob[#plaque]
    //     sprite(snum).member = member("plaque_" & glob[#plaque])
    //   end if
    // end
    // ```
    func exitFrame() {
        let currentPlaque = Glob.shared["plaque"].asString!
        if myPlaque != currentPlaque {
            myPlaque = currentPlaque
            sprite(snum).member = member("plaque_\(currentPlaque)")
        }
    }
}
