// Translated from Lingo: behavior_editor-choose color.ls

class BehaviorEditorChooseColor {
    var myColor: String = ""

    func getPropertyDescriptionList() -> [String: Any] {
        return ["myColor": ["comment": "Color:", "format": "string", "range": ["RED", "GREEN", "BLUE", "YELLOW", "BLACK", "WHITE", "GRAY"]]]
    }

    func mouseUp() {
        if glob.EDITOR["edit_manager"] != nil {
            glob.EDITOR.edit_manager.settoolcolor(myColor)
        }
        sendAllSprites("editor_setcolor", myColor)
    }
}
