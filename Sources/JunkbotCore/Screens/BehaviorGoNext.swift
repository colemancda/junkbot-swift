// Translated from Lingo: behavior_go next.ls

class BehaviorGoNext: LingoObject, @unchecked Sendable {
    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   go(#next)
    // end
    // ```
    func mouseUp() {
        go("next")
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
