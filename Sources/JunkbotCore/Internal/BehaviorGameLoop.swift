// Translated from Lingo: behavior_game_loop.ls

class BehaviorGameLoop: LingoObject, @unchecked Sendable {
  // Original Lingo body: exitframe
  // ```lingo
  // on exitFrame me
  //   SndCheckPlaylist()
  //   go(the frame)
  // end
  // ```
  func exitFrame() {
    SndCheckPlaylist()
    go("frame")  // loop on current frame
  }
}
