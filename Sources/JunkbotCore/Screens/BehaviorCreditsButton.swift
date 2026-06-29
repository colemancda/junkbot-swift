// Translated from Lingo: behavior_credits button.ls

class BehaviorCreditsButton {
    func mouseUp() {
        go("credits")
    }

    func mouseDown() {
        SndSFX("h_button1")
    }
}
