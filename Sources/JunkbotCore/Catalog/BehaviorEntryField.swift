// Translated from Lingo: behavior_entry field beh.ls

class BehaviorEntryField {
    var fld: LingoMember? = nil
    var maxchars: Int = 30

    init(_ spriteNum: Int) {
        fld = sprite(spriteNum).member
    }

    func keyDown(_ key: String) {
        if key == "\n" { return }
        let currentText = fld?.text ?? ""
        if currentText.count >= maxchars && selection == "" && key.unicodeScalars.first?.value != 8 {
            return
        }
        pass()
    }

    func getPropertyDescriptionList() -> PropList {
        let result = PropList()
        let maxcharsDesc = PropList()
        maxcharsDesc["comment"] = .string("Max chars:")
        maxcharsDesc["format"] = .string("integer")
        maxcharsDesc["default"] = .int(30)
        result["maxchars"] = .propList(maxcharsDesc)
        return result
    }
}
