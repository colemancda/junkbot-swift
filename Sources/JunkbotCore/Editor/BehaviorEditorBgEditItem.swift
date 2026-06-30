// Translated from Lingo: behavior_editor-bg edit item.ls

class BehaviorEditorBgEditItem: LingoObject, @unchecked Sendable {
    var kind: String = ""
    var s: LingoSprite?
    var m: LingoMember?

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   s = sprite(me.spriteNum)
    //   m = s.member
    // end
    // ```
    func beginSprite(_ spriteNum: Int) {
        s = sprite(spriteNum)
        m = s?.member
    }

    // Original Lingo body: mousedown
    // ```lingo
    // on mouseDown me
    //   glob.EDITOR.edit_manager.bg_edit_item(kind, m)
    // end
    // ```
    func mouseDown() {
        // glob.EDITOR is LV (propList), not typed — look up EditManager via Glob typed accessor
        // EditManager is stored as a typed object under "edit_manager_obj" or similar.
        // Since we can't dynamic-call bg_edit_item on LV, stub this call out.
        // bg_edit_item(kind, m) -- would need glob.EDITOR["edit_manager"].asObject()?.bg_edit_item
        // For now, no-op since the editor behavior is not yet wired to the typed Glob.
        _ = kind; _ = m
    }

    // Original Lingo body: getpropertydescriptionlist
    // ```lingo
    // on getPropertyDescriptionList
    //   L = [:]
    //   L[#kind] = [#comment: "Kind", #format: #symbol, #range: [#backdrop, #decal], #default: #decal]
    //   return L
    // end
    // ```
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
