// Translated from Lingo: behavior_entry field beh.ls

class BehaviorEntryField {
    var fld: Member? = nil
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

    func getPropertyDescriptionList() -> [String: Any] {
        return ["maxchars": ["comment": "Max chars:", "format": "integer", "default": 30]]
    }
}
