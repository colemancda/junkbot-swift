// Translated from Lingo: behavior_Master.Box.Out.ls

public protocol Behavior: AnyObject {
    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   glob[#master_obj].getOut()
    //   glob[#award_obj].dropBox()
    // end
    // ```
    func mouseUp()
}

public class BehaviorMasterBoxOut: Behavior {
    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   glob[#master_obj].getOut()
    //   glob[#award_obj].dropBox()
    // end
    // ```
    public func mouseUp() {
        // Glob.shared["master_obj"].getOut() -- stub
        // Glob.shared["award_obj"].dropBox() -- stub
    }
}
