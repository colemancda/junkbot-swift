// Translated from Lingo: behavior_catalog dev button behavior.ls

class BehaviorCatalogDevButton: LingoObject, @unchecked Sendable {
  var m: Member? = nil

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   m = sprite(me.spriteNum).member
  //   m.hilite = 0
  //   glob.catalog.catalog_manager.database = "alpha"
  // end
  // ```
  func beginSprite(_ spriteNum: Int) {
    m = sprite(spriteNum).member
    m?.hilite = false
    glob.catalog.catalog_manager.database = "alpha"
  }

  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   if m.hilite then
  //     glob.catalog.catalog_manager.database = "dev"
  //   else
  //     glob.catalog.catalog_manager.database = "alpha"
  //   end if
  //   glob.catalog.catalog_manager.catalog()
  // end
  // ```
  func mouseUp() {
    if m?.hilite == true {
      glob.catalog.catalog_manager.database = "dev"
    } else {
      glob.catalog.catalog_manager.database = "alpha"
    }
    glob.catalog.catalog_manager.catalog()
  }
}
