// Translated from Lingo: behavior_91.ls

class Behavior91: LingoObject, @unchecked Sendable {
  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   glob[#award_obj].updateState(#move2)
  // end
  // ```
  func mouseUp() {
    (Glob.shared["award_obj"]).updateState("move2")
  }
}
