// Translated from Lingo: behavior_ShowHint.ls

class BehaviorShowHint: LingoObject, @unchecked Sendable {
  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   sendAllSprites(#getOut)
  //   glob[#hint_obj].dropBox()
  // end
  // ```
  func mouseUp() {
    sendAllSprites("getOut")
    (Glob.shared["hint_obj"]).dropBox()
  }
}
