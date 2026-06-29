// Translated from Lingo: behavior_global button.ls

class BehaviorGlobalButton: LingoObject, @unchecked Sendable {
    var myMessage: String = "none"

    func mouseUp() {
        gbutton(myMessage)
    }
}
