// Translated from Lingo: behavior_catalog disable until net ready.ls

class BehaviorCatalogDisableUntilNetReady: LingoObject, @unchecked Sendable {
  var s: Sprite? = nil
  var m: Member? = nil

  // Original Lingo body: new
  // ```lingo
  // on new me
  //   s = sprite(me.spriteNum)
  //   m = s.member
  // end
  // ```
  init(_ spriteNum: Int) {
    super.init()
    s = sprite(spriteNum)
    m = s?.member
  }

  // Original Lingo body: netready
  // ```lingo
  // on netReady me, flag
  //   if flag = 1 then
  //     s.blend = 100
  //   else
  //     s.blend = 30
  //   end if
  // end
  // ```
  func netReady(_ flag: Int) {
    if flag == 1 {
      s?.blend = 100
    } else {
      s?.blend = 30
    }
  }
}
