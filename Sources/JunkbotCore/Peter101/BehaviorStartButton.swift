// Translated from Lingo: behavior_STARTBUTTON.ls

class BehaviorStartButton {
    var my: LingoSprite? = nil
    var myName: String = ""
    var spriteNum: Int = 0

    func beginSprite() {
        my = sprite(spriteNum)
        myName = my?.member?.name ?? ""
        my?.blend = 100
    }

    func mouseUp() {
        if !(Glob.shared["memo"].asString == "DidIt") {
            Glob.shared["memo"] = .string("show")
        }
        my?.member = member(myName)
        SndMusicEnd()
        go("levels")
    }

    func mouseDown() {
        SndSFX("h_button1")
    }

    func mouseWithin() {
        my?.member = member(myName + "_ro")
    }

    func mouseLeave() {
        my?.member = member(myName)
    }
}
