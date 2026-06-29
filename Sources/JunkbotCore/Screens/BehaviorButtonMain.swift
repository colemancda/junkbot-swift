// Translated from Lingo: behavior_button_Main.ls

class BehaviorButtonMain {
    func mouseUp() {
        (glob["PLAYER"] as AnyObject).game_manager.exitGame()
        (glob["download_manager"] as AnyObject).mainmenu()
    }

    func mouseDown() {
        SndSFX("h_button1")
    }
}
