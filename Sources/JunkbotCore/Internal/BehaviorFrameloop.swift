// Translated from Lingo: behavior_frameloop.ls

class BehaviorFrameloop: LingoObject {
    func exitFrame() {
        go("frame")  // loop on current frame
        SndCheckPlaylist()
    }
}
