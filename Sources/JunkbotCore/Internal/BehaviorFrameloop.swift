// Translated from Lingo: behavior_frameloop.ls

class BehaviorFrameloop: LingoObject, @unchecked Sendable {
    func exitFrame() {
        go("frame")  // loop on current frame
        SndCheckPlaylist()
    }
}
