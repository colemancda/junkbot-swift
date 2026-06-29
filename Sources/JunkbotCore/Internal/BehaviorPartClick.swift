// Translated from Lingo: behavior_part click behavior.ls

class BehaviorPartClick: LingoObject {
    var part: LV = .void

    init(p: LV) {
        part = p
    }

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

    func mouseWithin() {
        mouseEnter()
    }

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
