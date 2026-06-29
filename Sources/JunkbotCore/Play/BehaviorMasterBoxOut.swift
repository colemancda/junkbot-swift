// Translated from Lingo: behavior_Master.Box.Out.ls

public protocol Behavior: AnyObject {
    func mouseUp()
}

public class BehaviorMasterBoxOut: Behavior {
    public func mouseUp() {
        // Glob.shared["master_obj"].getOut() -- stub
        // Glob.shared["award_obj"].dropBox() -- stub
    }
}
