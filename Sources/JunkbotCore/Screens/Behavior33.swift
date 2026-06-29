// Translated from Lingo: behavior_33.ls

class Behavior33 {
    var spriteNum: Int = 0

    func mouseWithin() {
        let _ = glob["level_scrn_obj"] as? BehaviorScreenLoop
        (glob["level_scrn_obj"] as AnyObject).roTab(spriteNum, 100)
    }

    func mouseLeave() {
        (glob["level_scrn_obj"] as AnyObject).roTab(spriteNum, 0)
    }

    func mouseUp() {
        (glob["level_scrn_obj"] as AnyObject).tabClicked(spriteNum)
    }
}
