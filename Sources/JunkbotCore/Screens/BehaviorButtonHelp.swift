// Translated from Lingo: behavior_button-help.ls

class BehaviorButtonHelp {
    func mouseUp() {
        go("help")
    }

    func mouseDown() {
        SndSFX("h_button1")
    }
}
