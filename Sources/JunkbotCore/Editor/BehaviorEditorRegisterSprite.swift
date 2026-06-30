// Translated from Lingo: behavior_editor-register sprite beh.ls

class BehaviorEditorRegisterSprite {
    var myName: String = ""

    func beginSprite(_ spriteNum: Int) {
        glob.EDITOR[myName] = .object(sprite(spriteNum))
    }

    func getPropertyDescriptionList() -> PropList {
        var L = PropList()
        var desc = PropList()
        desc["comment"] = .string("Sprite name:")
        desc["format"] = .string("symbol")
        desc["default"] = .void
        L["myName"] = .propList(desc)
        return L
    }
}
