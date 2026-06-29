// Translated from Lingo: behavior_catalog dev button behavior.ls

class BehaviorCatalogDevButton {
    var m: Member? = nil

    func beginSprite(_ spriteNum: Int) {
        m = sprite(spriteNum).member
        m?.hilite = false
        glob.catalog.catalog_manager.database = "alpha"
    }

    func mouseUp() {
        if m?.hilite == true {
            glob.catalog.catalog_manager.database = "dev"
        } else {
            glob.catalog.catalog_manager.database = "alpha"
        }
        glob.catalog.catalog_manager.catalog()
    }
}
