// Translated from Lingo: behavior_editor-selectable tool.ls

class BehaviorEditorSelectableTool {
    var mytoolmode: String = "none"
    var mytoolparam: String? = nil
    var mytoolstate: String? = nil
    var mytoolframe: Int? = nil
    var s: LingoSprite?

    func beginSprite(_ spriteNum: Int) {
        s = sprite(spriteNum)
    }

    func mouseUp() {
        if !glob.EDITOR["edit_manager"].isVoid {
            glob.EDITOR["edit_manager"].settoolmode(mytoolmode, mytoolparam, mytoolstate, mytoolframe != nil ? mytoolframe! : 0)
        }
        if !glob.EDITOR["tool_highlight_box"].isVoid {
            glob.EDITOR["tool_highlight_box"].highlight(s)
        }
    }

    func getPropertyDescriptionList() -> PropList {
        let L = PropList()

        let modeDesc = PropList()
        modeDesc["comment"] = .string("Tool mode:")
        modeDesc["format"] = .string("symbol")
        modeDesc["default"] = .string("none")
        L["mytoolmode"] = .propList(modeDesc)

        let paramDesc = PropList()
        paramDesc["comment"] = .string("Tool param:")
        paramDesc["format"] = .string("symbol")
        paramDesc["default"] = .void
        L["mytoolparam"] = .propList(paramDesc)

        let stateDesc = PropList()
        stateDesc["comment"] = .string("Tool state:")
        stateDesc["format"] = .string("symbol")
        stateDesc["default"] = .void
        L["mytoolstate"] = .propList(stateDesc)

        let frameDesc = PropList()
        frameDesc["comment"] = .string("Tool frame:")
        frameDesc["format"] = .string("integer")
        frameDesc["default"] = .void
        L["mytoolframe"] = .propList(frameDesc)

        return L
    }
}
