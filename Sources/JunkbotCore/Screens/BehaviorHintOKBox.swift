// Translated from Lingo: behavior_Hint_OK_Box.ls

class BehaviorHintOKBox: LingoObject, @unchecked Sendable {
    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   glob[#hint_obj].updateState(#move2)
    // end
    // ```
    func mouseUp() {
        (Glob.shared["hint_obj"]).updateState("move2")
    }
}
