// Translated from Lingo: behavior_buttons_ro.ls

class BehaviorButtonsRo: LingoObject, @unchecked Sendable {
    var sp: LingoSprite? = nil
    var mem: String = ""
    var highlight: Int = 0
    var mwi: Int = 0
    var spriteNum: Int = 0

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   sp = sprite(me.spriteNum)
    //   mem = sp.member.name
    //   highlight = 0
    // end
    // ```
    func beginSprite() {
        sp = sprite(spriteNum)
        mem = sp?.member?.name ?? ""
        highlight = 0
    }

    // Original Lingo body: mousewithin
    // ```lingo
    // on mouseWithin me
    //   sp.member = member(mem & "_x")
    //   mwi = 1
    // end
    // ```
    func mouseWithin() {
        sp?.member = member(mem + "_x")
        mwi = 1
    }

    // Original Lingo body: mouseleave
    // ```lingo
    // on mouseLeave me
    //   if not highlight then
    //     sp.member = member(mem)
    //   end if
    //   mwi = 0
    // end
    // ```
    func mouseLeave() {
        if highlight == 0 {
            sp?.member = member(mem)
        }
        mwi = 0
    }

    // Original Lingo body: updateprop
    // ```lingo
    // on updateProp me
    //   mem = sp.member.name
    // end
    // ```
    func updateProp() {
        mem = sp?.member?.name ?? ""
    }

    // Original Lingo body: highlight
    // ```lingo
    // on highlight me, flag
    //   highlight = flag
    //   if flag or mwi then
    //     sp.member = member(mem & "_x")
    //   else
    //     sp.member = member(mem)
    //   end if
    // end
    // ```
    func highlight(_ flag: Int) {
        highlight = flag
        if flag != 0 || mwi != 0 {
            sp?.member = member(mem + "_x")
        } else {
            sp?.member = member(mem)
        }
    }
}
