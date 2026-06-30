// Translated from Lingo: behavior_127.ls

class Behavior127: LingoObject, @unchecked Sendable {
  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   go("ho-fame")
  // end
  // ```
  func mouseUp() {
    go("ho-fame")
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
