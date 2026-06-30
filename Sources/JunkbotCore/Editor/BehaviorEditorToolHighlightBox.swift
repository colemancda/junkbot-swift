// Translated from Lingo: behavior_editor-tool highlight box beh.ls

class BehaviorEditorToolHighlightBox {
    var s: Sprite?

    func beginSprite(_ spriteNum: Int) {
        s = sprite(spriteNum)
        s?.loc = Point(x: -100, y: -100)
        if let spr = s { glob.EDITOR["tool_highlight_box"] = .object(spr) }
    }

    func highlight(_ spr: Sprite) {
        // s.rect = spr.rect + rect(-4, -4, 4, 4)
        s?.rect = spr.rect.insetBy(dx: -4, dy: -4)
    }
}
