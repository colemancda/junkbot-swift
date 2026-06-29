// Translated from Lingo: behavior_editor-choose color.ls

class BehaviorEditorChooseColor {
    var myColor: String = ""

    func getPropertyDescriptionList() -> PropList {
        let L = PropList()
        let desc = PropList()
        desc["comment"] = .string("Color:")
        desc["format"] = .string("string")
        let range = LingoList()
        for c in ["RED", "GREEN", "BLUE", "YELLOW", "BLACK", "WHITE", "GRAY"] {
            range.add(.string(c))
        }
        desc["range"] = .list(range)
        L["myColor"] = .propList(desc)
        return L
    }

    func mouseUp() {
        if !glob.EDITOR["edit_manager"].isVoid {
            glob.EDITOR.edit_manager.settoolcolor(myColor)
        }
        sendAllSprites("editor_setcolor", .string(myColor))
    }
}
