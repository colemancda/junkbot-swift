// Translated from Lingo: behavior_editor-choose color.ls

class BehaviorEditorChooseColor: LingoObject, @unchecked Sendable {
    var myColor: String = ""

    // Original Lingo body: getpropertydescriptionlist
    // ```lingo
    // on getPropertyDescriptionList me
    //   return [#myColor: [#comment: "Color:", #format: #string, #range: ["RED", "GREEN", "BLUE", "YELLOW", "BLACK", "WHITE", "GRAY"]]]
    // end
    // ```
    func getPropertyDescriptionList() -> PropList {
        var L = PropList()
        var desc = PropList()
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

    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   global glob
    //   if glob.EDITOR[#edit_manager] <> VOID then
    //     glob.EDITOR.edit_manager.settoolcolor(myColor)
    //   end if
    //   sendAllSprites(#editor_setcolor, myColor)
    // end
    // ```
    func mouseUp() {
        if !glob.EDITOR["edit_manager"].isVoid {
            glob.EDITOR.edit_manager.settoolcolor(.string(myColor))
        }
        sendAllSprites("editor_setcolor", .string(myColor))
    }
}
