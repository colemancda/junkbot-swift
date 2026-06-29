// Translated from Lingo: behavior_HideBossMessage.ls

class BehaviorHideBossMessage {
    func mouseUp() {
        (Glob.shared["boss"]).hide()
    }

    func mouseDown() {
        SndSFX("h_button1")
    }
}
