// Translated from Lingo: behavior_global button.ls

class BehaviorGlobalButton: LingoObject, @unchecked Sendable {
    var myMessage: String = "none"

    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   gbutton(myMessage)
    // end
    // ```
    func mouseUp() {
        gbutton(myMessage)
    }
}
