// Translated from Lingo: behavior_frameloop.ls

class BehaviorFrameloop: BehaviorBase {
    func exitFrame() {
        go("frame")  // loop on current frame
        SndCheckPlaylist()
    }
}
