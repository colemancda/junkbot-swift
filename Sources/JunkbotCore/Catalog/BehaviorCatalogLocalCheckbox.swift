// Translated from Lingo: behavior_catalog local checkbox behavior.ls

class BehaviorCatalogLocalCheckbox {
    var m: Member? = nil

    func beginSprite(_ spriteNum: Int) {
        m = sprite(spriteNum).member
        // m.hilite = (the environment).internetConnected = #offline
        m?.hilite = !isInternetConnected()
    }

    func mouseUp() {
        if !isInternetConnected() {
            m?.hilite = false
        }
        glob.catalog.catalog_manager.localmode = m?.hilite ?? false
        glob.catalog.catalog_manager.catalog()
    }
}
