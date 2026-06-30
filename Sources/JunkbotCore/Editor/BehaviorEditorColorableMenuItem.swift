// Translated from Lingo: behavior_editor-colorable menu item.ls

class BehaviorEditorColorableMenuItem {
    var s: LingoSprite?
    var b: String = ""

    func beginSprite(_ spriteNum: Int) {
        s = sprite(spriteNum)
        b = s?.member.name ?? ""
        // Original: parse itemDelimiter "_", strip last item from b
        // The Lingo "delete char -30002 of b" removes the last item-delimited segment
        if let lastUnderscore = b.lastIndex(of: "_") {
            b = String(b[b.startIndex..<lastUnderscore])
        }
    }

    func editor_setcolor(_ c: String) {
        let memberName = b + "_" + c
        if let m = member(memberName) {
            s?.member = m
        } else {
            debugLog("\(b) \(c) failed")
        }
    }
}
