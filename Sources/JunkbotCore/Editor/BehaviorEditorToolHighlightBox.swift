// Translated from Lingo: behavior_editor-tool highlight box beh.ls

class BehaviorEditorToolHighlightBox: LingoObject, @unchecked Sendable {
    var s: Sprite?

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   s = sprite(me.spriteNum)
    //   s.loc = point(-100, -100)
    //   glob.EDITOR[#tool_highlight_box] = s
    // end
    // ```
    func beginSprite(_ spriteNum: Int) {
        s = sprite(spriteNum)
        s?.loc = Point(x: -100, y: -100)
        if let spr = s { glob.EDITOR["tool_highlight_box"] = .object(spr) }
    }

    // Original Lingo body: highlight
    // ```lingo
    // on highlight me, spr
    //   s.rect = spr.rect + rect(-4, -4, 4, 4)
    // end
    // ```
    func highlight(_ spr: Sprite) {
        // s.rect = spr.rect + rect(-4, -4, 4, 4)
        s?.rect = spr.rect.insetBy(dx: -4, dy: -4)
    }
}
