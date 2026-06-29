// Translated from Lingo: behavior_editor-tool highlight box beh.ls

class BehaviorEditorToolHighlightBox {
    var s: Sprite?

    func beginSprite(_ spriteNum: Int) {
        s = sprite(spriteNum)
        s?.loc = Point(x: -100, y: -100)
        glob.EDITOR["tool_highlight_box"] = s
    }

    func highlight(_ spr: Sprite) {
        // s.rect = spr.rect + rect(-4, -4, 4, 4)
        s?.rect = spr.rect.insetBy(dx: -4, dy: -4)
    }
}
