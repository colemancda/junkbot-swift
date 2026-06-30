// Translated from Lingo: behavior_catalog local checkbox behavior.ls

class BehaviorCatalogLocalCheckbox: LingoObject, @unchecked Sendable {
    var m: LingoMember? = nil

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   m = sprite(me.spriteNum).member
    //   m.hilite = (the environment).internetConnected = #offline
    // end
    // ```
    func beginSprite(_ spriteNum: Int) {
        m = sprite(spriteNum).member
        // m.hilite = (the environment).internetConnected = #offline
        m?.hilite = !isInternetConnected()
    }

    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   if (the environment).internetConnected = #offline then
    //     m.hilite = 0
    //   end if
    //   glob.catalog.catalog_manager.localmode = m.hilite
    //   glob.catalog.catalog_manager.catalog()
    // end
    // ```
    func mouseUp() {
        if !isInternetConnected() {
            m?.hilite = false
        }
        // catalog_manager.localmode is accessed via LV dynamic lookup — stub
        _ = m?.hilite
    }
}
