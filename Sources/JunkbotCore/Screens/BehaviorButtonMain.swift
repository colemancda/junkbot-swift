// Translated from Lingo: behavior_button_Main.ls

class BehaviorButtonMain {
    func mouseUp() {
        (Glob.shared["PLAYER"]).game_manager.exitGame()
        (Glob.shared["download_manager"]).mainmenu()
    }

    func mouseDown() {
        SndSFX("h_button1")
    }
}
