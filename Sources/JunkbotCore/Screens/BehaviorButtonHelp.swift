// Translated from Lingo: behavior_button-help.ls

class BehaviorButtonHelp: LingoObject, @unchecked Sendable {
  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   go("help")
  // end
  // ```
  func mouseUp() {
    go("help")
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
