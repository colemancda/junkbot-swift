// Translated from Lingo: behavior_HideBossMessage.ls

class BehaviorHideBossMessage: LingoObject, @unchecked Sendable {
  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   glob[#boss].hide()
  // end
  // ```
  func mouseUp() {
    (Glob.shared["boss"]).hide()
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
