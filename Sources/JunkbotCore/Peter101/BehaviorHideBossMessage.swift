// Translated from Lingo: behavior_HideBossMessage.ls

class BehaviorHideBossMessage {
    func mouseUp() {
        (glob["boss"] as AnyObject).hide()
    }

    func mouseDown() {
        SndSFX("h_button1")
    }
}
