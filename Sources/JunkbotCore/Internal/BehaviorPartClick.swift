// Translated from Lingo: behavior_part click behavior.ls

class BehaviorPartClick: LingoObject, @unchecked Sendable {
    var part: LV = .void

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   return me
    // end
    // ```
    init(p: LV) {
        self.part = p
        super.init()
    }

    // Original Lingo body: mouseenter
    // ```lingo
    // on mouseEnter me
    //   if voidp(glob.PLAYER[#partclick_recipient]) then
    //     return 
    //   end if
    //   glob.PLAYER.partclick_recipient.partclick(part, #mouseEnter)
    // end
    // ```
    func mouseEnter() {
        // if voidp(glob.PLAYER[#partclick_recipient]): return
        // glob.PLAYER.partclick_recipient.partclick(part, #mouseEnter)
        let player = Glob.shared["PLAYER"]
        guard !player.isVoid else { return }
        let recipient = player.asPropList?["partclick_recipient"]
        guard let r = recipient, !r.isVoid else { return }
        // r.partclick(part, "mouseEnter")
        _ = r
    }

    // Original Lingo body: mousewithin
    // ```lingo
    // on mouseWithin me
    //   me.mouseEnter()
    // end
    // ```
    func mouseWithin() {
        mouseEnter()
    }

    // Original Lingo body: mouseleave
    // ```lingo
    // on mouseLeave me
    //   if voidp(glob.PLAYER[#partclick_recipient]) then
    //     return 
    //   end if
    //   glob.PLAYER.partclick_recipient.partclick(part, #mouseLeave)
    // end
    // ```
    func mouseLeave() {
        // if voidp(glob.PLAYER[#partclick_recipient]): return
        // glob.PLAYER.partclick_recipient.partclick(part, #mouseLeave)
        let player = Glob.shared["PLAYER"]
        guard !player.isVoid else { return }
        let recipient = player.asPropList?["partclick_recipient"]
        guard let r = recipient, !r.isVoid else { return }
        // r.partclick(part, "mouseLeave")
        _ = r
    }
}
