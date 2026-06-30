// Translated from Lingo: behavior_hof page buttons behavior.ls

class BehaviorHOFPageButtons {
    var sp: LingoSprite? = nil
    var mem: String = ""
    var highlight: Int = 0
    var mwi: Int = 0
    var dir: String = "prev"
    var hofSprite: LingoSprite? = nil
    var spriteNum: Int = 0

    // Property description: dir is #symbol with range [#prev, #next], default #prev

    func beginSprite() {
        sp = sprite(spriteNum)
        mem = sp?.member?.name ?? ""
        highlight = 0
        hofSprite = sprite(8)
    }

    func mouseWithin() {
        if hofSprite?.pageP(dir) != 0 {
            sp?.member = member(mem + "_x")
            mwi = 1
        }
    }

    func mouseLeave() {
        if highlight == 0 {
            sp?.member = member(mem)
        }
        mwi = 0
    }

    func updateProp() {
        mem = sp?.member?.name ?? ""
    }

    func highlight(_ flag: Int) {
        highlight = flag
        if flag != 0 || mwi != 0 {
            sp?.member = member(mem + "_x")
        } else {
            sp?.member = member(mem)
        }
    }

    func mouseDown() {
        if hofSprite?.pageP(dir) != 0 {
            SndSFX("h_button1")
        }
    }

    func mouseUp() {
        if hofSprite?.pageP(dir) != 0 {
            hofSprite?.page(dir)
        }
    }
}
