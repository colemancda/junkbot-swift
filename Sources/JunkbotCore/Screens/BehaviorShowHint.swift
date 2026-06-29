// Translated from Lingo: behavior_ShowHint.ls

class BehaviorShowHint {
    func mouseUp() {
        sendAllSprites("getOut")
        (Glob.shared["hint_obj"] as AnyObject).dropBox()
    }
}
