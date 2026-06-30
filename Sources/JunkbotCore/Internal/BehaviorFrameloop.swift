// Translated from Lingo: behavior_frameloop.ls

class BehaviorFrameloop: LingoObject, @unchecked Sendable {
  // Original Lingo body: exitframe
  // ```lingo
  // on exitFrame me
  //   go(the frame)
  // end
  // ```
  func exitFrame() {
    go("frame")  // loop on current frame
    SndCheckPlaylist()
  }
}
