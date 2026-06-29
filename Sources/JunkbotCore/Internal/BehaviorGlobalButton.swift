// Translated from Lingo: behavior_global button.ls

class BehaviorGlobalButton: LingoObject {
    var myMessage: String = "none"

    func mouseUp() {
        gbutton(myMessage)
    }
}
