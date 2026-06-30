// Translated from Lingo: behavior_go prev.ls

class BehaviorGoPrev: LingoObject, @unchecked Sendable {
  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   go(#previous)
  // end
  // ```
  func mouseUp() {
    go("previous")
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
