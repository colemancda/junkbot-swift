// Translated from Lingo: behavior_button_Main.ls

class BehaviorButtonMain: LingoObject, @unchecked Sendable {
    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   glob.PLAYER.game_manager.exitGame()
    //   glob.download_manager.mainmenu()
    // end
    // ```
    func mouseUp() {
        (Glob.shared["PLAYER"]).game_manager.exitGame()
        (Glob.shared["download_manager"]).mainmenu()
    }

    // Original Lingo body: mousedown
    // ```lingo
    // on mouseDown me
    //   SndSFX("h_button1")
    // end
    // ```
    func mouseDown() {
        SndSFX("h_button1")
    }
}
