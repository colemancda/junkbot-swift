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
        // glob.EDITOR is LV (propList), not typed — look up EditManager via Glob typed accessor
        // EditManager is stored as a typed object under "edit_manager_obj" or similar.
        // Since we can't dynamic-call bg_edit_item on LV, stub this call out.
        // bg_edit_item(kind, m) -- would need glob.EDITOR["edit_manager"].asObject()?.bg_edit_item
        // For now, no-op since the editor behavior is not yet wired to the typed Glob.
        _ = kind; _ = m
    }

    func getPropertyDescriptionList() -> PropList {
        var L = PropList()
        var kindDesc = PropList()
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
