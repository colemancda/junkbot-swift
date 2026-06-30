// Translated from Lingo: behavior_go menu.ls

class BehaviorGoMenu: LingoObject, @unchecked Sendable {
  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   global glob
  //   glob.download_manager.mainmenu()
  // end
  // ```
  func mouseUp() {
    (Glob.shared["download_manager"]).mainmenu()
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
