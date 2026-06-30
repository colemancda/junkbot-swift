// Translated from Lingo: behavior_hof page buttons behavior.ls

class BehaviorHOFPageButtons: LingoObject, @unchecked Sendable {
    var sp: LingoSprite? = nil
    var mem: String = ""
    var highlight: Int = 0
    var mwi: Int = 0
    var dir: String = "prev"
    var hofSprite: LingoSprite? = nil
    var spriteNum: Int = 0

    // Property description: dir is #symbol with range [#prev, #next], default #prev

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   sp = sprite(me.spriteNum)
    //   mem = sp.member.name
    //   highlight = 0
    //   hof_sprite = sprite(8)
    // end
    // ```
    func beginSprite() {
        sp = sprite(spriteNum)
        mem = sp?.member?.name ?? ""
        highlight = 0
        hofSprite = sprite(8)
    }

    // Original Lingo body: mousewithin
    // ```lingo
    // on mouseWithin me
    //   if hof_sprite.pageP(dir) then
    //     sp.member = member(mem & "_x")
    //     mwi = 1
    //   end if
    // end
    // ```
    func mouseWithin() {
        if hofSprite?.pageP(dir) != 0 {
            sp?.member = member(mem + "_x")
            mwi = 1
        }
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

    // Original Lingo body: mousedown
    // ```lingo
    // on mouseDown me
    //   if hof_sprite.pageP(dir) then
    //     SndSFX("h_button1")
    //   end if
    // end
    // ```
    func mouseDown() {
        if hofSprite?.pageP(dir) != 0 {
            SndSFX("h_button1")
        }
    }

    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   if hof_sprite.pageP(dir) then
    //     hof_sprite.page(dir)
    //   end if
    // end
    // ```
    func mouseUp() {
        if hofSprite?.pageP(dir) != 0 {
            hofSprite?.page(dir)
        }
    }
}
