// Translated from Lingo: behavior_entry field beh.ls

class BehaviorEntryField: LingoObject, @unchecked Sendable {
    var fld: LingoMember? = nil
    var maxchars: Int = 30

    // Original Lingo body: new
    // ```lingo
    // on new me
    //   fld = sprite(me.spriteNum).member
    // end
    // ```
    init(_ spriteNum: Int) {
        super.init()
        fld = sprite(spriteNum).member
    }

    // Original Lingo body: keydown
    // ```lingo
    // on keyDown me
    //   k = the key
    //   if k = RETURN then
    //     return 
    //   end if
    //   if (fld.text.length >= maxchars) and (the selection = EMPTY) and (charToNum(k) <> 8) then
    //     return 
    //   end if
    //   pass()
    // end
    // ```
    func keyDown(_ key: String) {
        if key == "\n" { return }
        let currentText = fld?.text ?? ""
        if currentText.count >= maxchars && selection == "" && key.unicodeScalars.first?.value != 8 {
            return
        }
        pass()
    }

    // Original Lingo body: getpropertydescriptionlist
    // ```lingo
    // on getPropertyDescriptionList me
    //   return [#maxchars: [#comment: "Max chars:", #format: #integer, #default: 30]]
    // end
    // ```
    func getPropertyDescriptionList() -> PropList {
        var result = PropList()
        var maxcharsDesc = PropList()
        maxcharsDesc["comment"] = .string("Max chars:")
        maxcharsDesc["format"] = .string("integer")
        maxcharsDesc["default"] = .int(30)
        result["maxchars"] = .propList(maxcharsDesc)
        return result
    }
}
