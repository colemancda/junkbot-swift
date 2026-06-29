// Translated from Lingo: behavior_button_Main.ls

class BehaviorButtonMain {
    func mouseUp() {
        (Glob.shared["PLAYER"] as AnyObject).game_manager.exitGame()
        (Glob.shared["download_manager"] as AnyObject).mainmenu()
    }

    func mouseDown() {
        SndSFX("h_button1")
    }
}
