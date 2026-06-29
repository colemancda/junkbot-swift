// Translated from Lingo: behavior_Hint_OK_Box.ls

class BehaviorHintOKBox {
    func mouseUp() {
        (Glob.shared["hint_obj"] as AnyObject).updateState("move2")
    }
}
