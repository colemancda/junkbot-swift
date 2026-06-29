// Translated from Lingo: behavior_game_loop.ls

class BehaviorGameLoop: BehaviorBase {
    func exitFrame() {
        SndCheckPlaylist()
        go("frame")  // loop on current frame
    }
}
