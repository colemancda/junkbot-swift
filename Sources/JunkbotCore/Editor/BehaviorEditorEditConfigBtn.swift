// Translated from Lingo: behavior_editor-edit config btn.ls

class BehaviorEditorEditConfigBtn {
    var m: Member?
    var configfield: Member?

    func beginSprite(_ spriteNum: Int) {
        m = sprite(spriteNum).member
        m?.text = "EDIT"
        configfield = member("config field")
    }

    func mouseUp() {
        if configfield?.editable == true {
            m?.text = "EDIT"
            configfield?.editable = false
            configfield?.bgColor = rgb(128, 128, 128)
            glob.EDITOR.edit_manager.setConfig()
        } else {
            m?.text = "COMMIT"
            configfield?.editable = true
            configfield?.bgColor = rgb(256, 256, 256)
        }
    }
}
