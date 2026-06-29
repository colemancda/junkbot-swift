// Translated from Lingo: behavior_editor-register sprite beh.ls

class BehaviorEditorRegisterSprite {
    var myName: String = ""

    func beginSprite(_ spriteNum: Int) {
        glob.EDITOR[myName] = sprite(spriteNum)
    }

    func getPropertyDescriptionList() -> [String: Any] {
        return ["myName": ["comment": "Sprite name:", "format": "symbol", "default": nil as Any?]]
    }
}
