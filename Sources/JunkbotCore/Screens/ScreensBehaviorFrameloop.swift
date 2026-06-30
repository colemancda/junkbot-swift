// Translated from Lingo: behavior_frameloop.ls

class ScreensBehaviorFrameloop: LingoObject, @unchecked Sendable {
    // Original Lingo body: exitframe
    // ```lingo
    // on exitFrame me
    //   go(the frame)
    // end
    // ```
    func exitFrame() {
        go(theFrame)
    }
}
