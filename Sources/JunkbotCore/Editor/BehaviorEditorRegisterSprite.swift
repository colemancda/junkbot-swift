// Translated from Lingo: behavior_editor-register sprite beh.ls

class BehaviorEditorRegisterSprite: LingoObject, @unchecked Sendable {
  var myName: String = ""

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   glob.EDITOR[myName] = sprite(me.spriteNum)
  // end
  // ```
  func beginSprite(_ spriteNum: Int) {
    glob.EDITOR[myName] = .object(sprite(spriteNum))
  }

  // Original Lingo body: getpropertydescriptionlist
  // ```lingo
  // on getPropertyDescriptionList
  //   return [#myName: [#comment: "Sprite name:", #format: #symbol, #default: VOID]]
  // end
  // ```
  func getPropertyDescriptionList() -> PropList {
    var L = PropList()
    var desc = PropList()
    desc["comment"] = .string("Sprite name:")
    desc["format"] = .string("symbol")
    desc["default"] = .void
    L["myName"] = .propList(desc)
    return L
  }
}
