// Translated from Lingo: behavior_33.ls

class Behavior33 {
    var spriteNum: Int = 0

    func mouseWithin() {
        (Glob.shared["level_scrn_obj"] as AnyObject).roTab(spriteNum, 100)
    }

    func mouseLeave() {
        (Glob.shared["level_scrn_obj"] as AnyObject).roTab(spriteNum, 0)
    }

    func mouseUp() {
        (Glob.shared["level_scrn_obj"] as AnyObject).tabClicked(spriteNum)
    }
}
