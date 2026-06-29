// Translated from Lingo: behavior_part click behavior.ls

class BehaviorPartClick {
    var part: Any? = nil

    // Reference to global state (injected externally)
    var glob: [String: Any] = [:]

    init(p: Any) {
        part = p
    }

    func mouseEnter() {
        // if voidp(glob.PLAYER[#partclick_recipient]): return
        // glob.PLAYER.partclick_recipient.partclick(part, #mouseEnter)
        guard let player = glob["PLAYER"] as? [String: Any],
              let recipient = player["partclick_recipient"] else { return }
        // recipient.partclick(part, "mouseEnter")
        _ = recipient
    }

    func mouseWithin() {
        mouseEnter()
    }

    func mouseLeave() {
        // if voidp(glob.PLAYER[#partclick_recipient]): return
        // glob.PLAYER.partclick_recipient.partclick(part, #mouseLeave)
        guard let player = glob["PLAYER"] as? [String: Any],
              let recipient = player["partclick_recipient"] else { return }
        // recipient.partclick(part, "mouseLeave")
        _ = recipient
    }
}
