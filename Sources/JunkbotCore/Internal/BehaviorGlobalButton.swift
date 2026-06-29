// Translated from Lingo: behavior_global button.ls

class BehaviorGlobalButton: BehaviorBase {
    var myMessage: String = "none"

    func mouseUp() {
        gbutton(myMessage)
    }
}
