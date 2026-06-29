// Translated from Lingo: behavior_33.ls

class Behavior33 {
    var spriteNum: Int = 0

    func mouseWithin() {
        (Glob.shared["level_scrn_obj"]).roTab(.int(spriteNum), 100)
    }

    func mouseLeave() {
        (Glob.shared["level_scrn_obj"]).roTab(.int(spriteNum), 0)
    }

    func mouseUp() {
        (Glob.shared["level_scrn_obj"]).tabClicked(.int(spriteNum))
    }
}
