// Translated from Lingo: behavior_frameloop.ls

class BehaviorFrameloop {
    func exitFrame() {
        go(frame: currentFrame())  // stub: go(the frame) — loop on current frame
        SndCheckPlaylist()
    }

    // Stubs
    func currentFrame() -> Int { return 0 }
    func go(frame: Int) { /* stub */ }
    func SndCheckPlaylist() { /* stub — implemented in MovieSoundCode */ }
}
