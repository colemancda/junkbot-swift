// Translated from Lingo: behavior_OK-hall-of-fame.ls

class BehaviorOKHallOfFame: LingoObject, @unchecked Sendable {
  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   go("levels")
  // end
  // ```
  func mouseUp() {
    go("levels")
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
