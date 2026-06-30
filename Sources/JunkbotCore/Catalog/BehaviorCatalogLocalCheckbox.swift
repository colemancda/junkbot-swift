// Translated from Lingo: behavior_catalog local checkbox behavior.ls

class BehaviorCatalogLocalCheckbox {
    var m: LingoMember? = nil

    func beginSprite(_ spriteNum: Int) {
        m = sprite(spriteNum).member
        // m.hilite = (the environment).internetConnected = #offline
        m?.hilite = !isInternetConnected()
    }

    func mouseUp() {
        if !isInternetConnected() {
            m?.hilite = false
        }
        // catalog_manager.localmode is accessed via LV dynamic lookup — stub
        _ = m?.hilite
    }
}
