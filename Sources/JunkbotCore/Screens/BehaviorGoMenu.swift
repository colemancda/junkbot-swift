// Translated from Lingo: behavior_go menu.ls

class BehaviorGoMenu {
    func mouseUp() {
        (Glob.shared["download_manager"] as AnyObject).mainmenu()
    }

    func mouseDown() {
        SndSFX("h_button1")
    }
}
