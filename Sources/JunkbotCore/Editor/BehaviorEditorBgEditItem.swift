// Translated from Lingo: behavior_editor-bg edit item.ls

class BehaviorEditorBgEditItem {
    var kind: String = ""
    var s: LingoSprite?
    var m: LingoMember?

    func beginSprite(_ spriteNum: Int) {
        s = sprite(spriteNum)
        m = s?.member
    }

    func mouseDown() {
        glob.EDITOR.edit_manager.bg_edit_item(kind, m)
    }

    func getPropertyDescriptionList() -> PropList {
        let L = PropList()
        let kindDesc = PropList()
        kindDesc["comment"] = .string("Kind")
        kindDesc["format"] = .string("symbol")
        let kindRange = LingoList()
        kindRange.add(.string("backdrop"))
        kindRange.add(.string("decal"))
        kindDesc["range"] = .list(kindRange)
        kindDesc["default"] = .string("decal")
        L["kind"] = .propList(kindDesc)
        return L
    }
}
