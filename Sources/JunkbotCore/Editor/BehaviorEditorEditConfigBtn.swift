// Translated from Lingo: behavior_editor-edit config btn.ls

class BehaviorEditorEditConfigBtn: LingoObject, @unchecked Sendable {
  var m: Member?
  var configfield: Member?

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   m = sprite(me.spriteNum).member
  //   m.text = "EDIT"
  //   configfield = member("config field")
  // end
  // ```
  func beginSprite(_ spriteNum: Int) {
    m = sprite(spriteNum).member
    m?.text = "EDIT"
    configfield = member("config field")
  }

  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   global glob
  //   if configfield.editable then
  //     m.text = "EDIT"
  //     configfield.editable = 0
  //     configfield.bgColor = rgb(128, 128, 128)
  //     glob.EDITOR.edit_manager.setConfig()
  //   else
  //     m.text = "COMMIT"
  //     configfield.editable = 1
  //     configfield.bgColor = rgb(256, 256, 256)
  //   end if
  // end
  // ```
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
