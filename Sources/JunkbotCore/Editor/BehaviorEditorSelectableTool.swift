// Translated from Lingo: behavior_editor-selectable tool.ls

class BehaviorEditorSelectableTool {
    var mytoolmode: String = "none"
    var mytoolparam: String? = nil
    var mytoolstate: String? = nil
    var mytoolframe: Int? = nil
    var s: Sprite?

    func beginSprite(_ spriteNum: Int) {
        s = sprite(spriteNum)
    }

    func mouseUp() {
        if glob.EDITOR["edit_manager"] != nil {
            glob.EDITOR["edit_manager"].settoolmode(mytoolmode, mytoolparam, mytoolstate, mytoolframe != nil ? mytoolframe! : 0)
        }
        if glob.EDITOR["tool_highlight_box"] != nil {
            glob.EDITOR["tool_highlight_box"].highlight(s)
        }
    }

    func getPropertyDescriptionList() -> [String: Any] {
        return [
            "mytoolmode": ["comment": "Tool mode:", "format": "symbol", "default": "none"],
            "mytoolparam": ["comment": "Tool param:", "format": "symbol", "default": nil as Any?],
            "mytoolstate": ["comment": "Tool state:", "format": "symbol", "default": nil as Any?],
            "mytoolframe": ["comment": "Tool frame:", "format": "integer", "default": nil as Any?]
        ]
    }
}
