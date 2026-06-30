// Translated from Lingo: behavior_credits button.ls

class BehaviorCreditsButton: LingoObject, @unchecked Sendable {
    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   go("credits")
    // end
    // ```
    func mouseUp() {
        go("credits")
    }

    // Original Lingo body: mousedown
    // ```lingo
    // on mouseDown me
    //   SndSFX("h_button1")
    // end
    // ```
    func mouseDown() {
        SndSFX("h_button1")
    }
}
