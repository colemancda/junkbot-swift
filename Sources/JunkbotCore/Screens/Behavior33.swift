// Translated from Lingo: behavior_33.ls

class Behavior33: LingoObject, @unchecked Sendable {
  var spriteNum: Int = 0

  // Original Lingo body: mousewithin
  // ```lingo
  // on mouseWithin me
  //   locked = glob[#level_scrn_obj].roTab(me.spriteNum, 100)
  // end
  // ```
  func mouseWithin() {
    (Glob.shared["level_scrn_obj"]).roTab(.int(spriteNum), 100)
  }

  // Original Lingo body: mouseleave
  // ```lingo
  // on mouseLeave me
  //   glob[#level_scrn_obj].roTab(me.spriteNum, 0)
  // end
  // ```
  func mouseLeave() {
    (Glob.shared["level_scrn_obj"]).roTab(.int(spriteNum), 0)
  }

  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   glob[#level_scrn_obj].tabClicked(me.spriteNum)
  // end
  // ```
  func mouseUp() {
    (Glob.shared["level_scrn_obj"]).tabClicked(.int(spriteNum))
  }
}
