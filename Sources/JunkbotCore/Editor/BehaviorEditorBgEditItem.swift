// Translated from Lingo: behavior_editor-bg edit item.ls

class BehaviorEditorBgEditItem {
    var kind: String = ""
    var s: Sprite?
    var m: Member?

    func beginSprite(_ spriteNum: Int) {
        s = sprite(spriteNum)
        m = s?.member
    }

    func mouseDown() {
        glob.EDITOR.edit_manager.bg_edit_item(kind, m)
    }

    func getPropertyDescriptionList() -> [String: Any] {
        var L = [String: Any]()
        L["kind"] = ["comment": "Kind", "format": "symbol", "range": ["backdrop", "decal"], "default": "decal"]
        return L
    }
}
