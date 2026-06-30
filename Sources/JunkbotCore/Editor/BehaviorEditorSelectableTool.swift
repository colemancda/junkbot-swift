// Translated from Lingo: behavior_editor-selectable tool.ls

class BehaviorEditorSelectableTool: LingoObject, @unchecked Sendable {
  var mytoolmode: String = "none"
  var mytoolparam: String? = nil
  var mytoolstate: String? = nil
  var mytoolframe: Int? = nil
  var s: LingoSprite?

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   s = sprite(me.spriteNum)
  // end
  // ```
  func beginSprite(_ spriteNum: Int) {
    s = sprite(spriteNum)
  }

  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   global glob
  //   if glob.EDITOR[#edit_manager] <> VOID then
  //     glob.EDITOR[#edit_manager].settoolmode(symbol(mytoolmode), symbol(mytoolparam), symbol(mytoolstate), integer(mytoolframe))
  //   end if
  //   if glob.EDITOR[#tool_highlight_box] <> VOID then
  //     glob.EDITOR[#tool_highlight_box].highlight(s)
  //   end if
  // end
  // ```
  func mouseUp() {
    if !glob.EDITOR["edit_manager"].isVoid {
      glob.EDITOR["edit_manager"].settoolmode(
        .string(mytoolmode), mytoolparam.map { .string($0) } ?? .void,
        mytoolstate.map { .string($0) } ?? .void, .int(mytoolframe ?? 0))
    }
    if !glob.EDITOR["tool_highlight_box"].isVoid {
      s.map { glob.EDITOR["tool_highlight_box"].highlight(.object($0)) }
    }
  }

  // Original Lingo body: getpropertydescriptionlist
  // ```lingo
  // on getPropertyDescriptionList me
  //   return [#mytoolmode: [#comment: "Tool mode:", #format: #symbol, #default: #none], #mytoolparam: [#comment: "Tool param:", #format: #symbol, #default: VOID], #mytoolstate: [#comment: "Tool state:", #format: #symbol, #default: VOID], #mytoolframe: [#comment: "Tool frame:", #format: #integer, #default: VOID]]
  // end
  // ```
  func getPropertyDescriptionList() -> PropList {
    var L = PropList()

    var modeDesc = PropList()
    modeDesc["comment"] = .string("Tool mode:")
    modeDesc["format"] = .string("symbol")
    modeDesc["default"] = .string("none")
    L["mytoolmode"] = .propList(modeDesc)

    var paramDesc = PropList()
    paramDesc["comment"] = .string("Tool param:")
    paramDesc["format"] = .string("symbol")
    paramDesc["default"] = .void
    L["mytoolparam"] = .propList(paramDesc)

    var stateDesc = PropList()
    stateDesc["comment"] = .string("Tool state:")
    stateDesc["format"] = .string("symbol")
    stateDesc["default"] = .void
    L["mytoolstate"] = .propList(stateDesc)

    var frameDesc = PropList()
    frameDesc["comment"] = .string("Tool frame:")
    frameDesc["format"] = .string("integer")
    frameDesc["default"] = .void
    L["mytoolframe"] = .propList(frameDesc)

    return L
  }
}
