// Translated from Lingo: behavior_game_loop.ls

class BehaviorGameLoop: LingoObject {
    func exitFrame() {
        SndCheckPlaylist()
        go("frame")  // loop on current frame
    }
}
