// Translated from Lingo: behavior_STARTBUTTON.ls

class BehaviorStartButton {
    var my: Any? = nil
    var myName: String = ""
    var spriteNum: Int = 0

    func beginSprite() {
        my = sprite(spriteNum)
        myName = (my as AnyObject).member.name as! String
        (my as AnyObject).blend = 100
    }

    func mouseUp() {
        if !((glob["memo"] as? String) == "DidIt") {
            glob["memo"] = "show"
        }
        (my as AnyObject).member = member(myName)
        SndMusicEnd()
        go("levels")
    }

    func mouseDown() {
        SndSFX("h_button1")
    }

    func mouseWithin() {
        (my as AnyObject).member = member(myName + "_ro")
    }

    func mouseLeave() {
        (my as AnyObject).member = member(myName)
    }
}
