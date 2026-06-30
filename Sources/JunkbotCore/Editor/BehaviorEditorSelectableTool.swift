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
            glob.EDITOR["edit_manager"].settoolmode(.string(mytoolmode), mytoolparam.map { .string($0) } ?? .void, mytoolstate.map { .string($0) } ?? .void, .int(mytoolframe ?? 0))
        }
        if !glob.EDITOR["tool_highlight_box"].isVoid {
            s.map { glob.EDITOR["tool_highlight_box"].highlight(.object($0)) }
        }
    }

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
