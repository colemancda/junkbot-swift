// Translated from Lingo: behavior_hof page buttons behavior.ls

class BehaviorHOFPageButtons {
    var sp: Any? = nil
    var mem: String = ""
    var highlight: Int = 0
    var mwi: Int = 0
    var dir: String = "prev"
    var hofSprite: Any? = nil
    var spriteNum: Int = 0

    // Property description: dir is #symbol with range [#prev, #next], default #prev

    func beginSprite() {
        sp = sprite(spriteNum)
        mem = (sp as AnyObject).member.name as! String
        highlight = 0
        hofSprite = sprite(8)
    }

    func mouseWithin() {
        if (hofSprite as AnyObject).pageP(dir) != 0 {
            (sp as AnyObject).member = member(mem + "_x")
            mwi = 1
        }
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

    func mouseDown() {
        if (hofSprite as AnyObject).pageP(dir) != 0 {
            SndSFX("h_button1")
        }
    }

    func mouseUp() {
        if (hofSprite as AnyObject).pageP(dir) != 0 {
            (hofSprite as AnyObject).page(dir)
        }
    }
}
