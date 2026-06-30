// Translated from Lingo: behavior_editor-colorable menu item.ls

class BehaviorEditorColorableMenuItem: LingoObject, @unchecked Sendable {
  var s: LingoSprite?
  var b: String = ""

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   s = sprite(me.spriteNum)
  //   b = s.member.name
  //   id = the itemDelimiter
  //   the itemDelimiter = "_"
  //   delete char -30002 of b
  //   the itemDelimiter = id
  // end
  // ```
  func beginSprite(_ spriteNum: Int) {
    s = sprite(spriteNum)
    b = s?.member?.name ?? ""
    // Original: parse itemDelimiter "_", strip last item from b
    // The Lingo "delete char -30002 of b" removes the last item-delimited segment
    if let lastUnderscore = b.lastIndex(of: "_") {
      b = String(b[b.startIndex..<lastUnderscore])
    }
  }

  // Original Lingo body: editor_setcolor
  // ```lingo
  // on editor_setcolor me, c
  //   m = member(b & "_" & c)
  //   if m.memberNum > 0 then
  //     s.member = m
  //   else
  //     put b && c && #failed
  //   end if
  // end
  // ```
  func editor_setcolor(_ c: String) {
    let memberName = b + "_" + c
    if let m = member(memberName) {
      s?.member = m
    } else {
      debugLog("\(b) \(c) failed")
    }
  }
}
