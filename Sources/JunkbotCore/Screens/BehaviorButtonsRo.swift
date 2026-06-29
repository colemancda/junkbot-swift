// Translated from Lingo: behavior_buttons_ro.ls

class BehaviorButtonsRo {
    var sp: Any? = nil
    var mem: String = ""
    var highlight: Int = 0
    var mwi: Int = 0
    var spriteNum: Int = 0

    func beginSprite() {
        sp = sprite(spriteNum)
        mem = (sp as AnyObject).member.name as! String
        highlight = 0
    }

    func mouseWithin() {
        (sp as AnyObject).member = member(mem + "_x")
        mwi = 1
    }

    func mouseLeave() {
        if highlight == 0 {
            (sp as AnyObject).member = member(mem)
        }
        mwi = 0
    }

    func updateProp() {
        mem = (sp as AnyObject).member.name as! String
    }

    func highlight(_ flag: Int) {
        highlight = flag
        if flag != 0 || mwi != 0 {
            (sp as AnyObject).member = member(mem + "_x")
        } else {
            (sp as AnyObject).member = member(mem)
        }
    }
}
