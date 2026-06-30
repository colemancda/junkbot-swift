// Translated from Lingo: behavior_HideRankBox.ls

class BehaviorHideRankBox: LingoObject, @unchecked Sendable {
  var spriteNum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   glob.PLAYER[#game_manager].TotalKeys()
  //   if glob[#rankdata][#keys] = glob[#hof] then
  //     sprite(me.spriteNum).loc = point(1000, 1000)
  //   else
  //     sprite(me.spriteNum).loc = point(487, 220)
  //   end if
  // end
  // ```
  func beginSprite() {
    (Glob.shared["PLAYER"]).game_manager.TotalKeys()
    let rankdata = Glob.shared["rankdata"].asPropList!
    if (rankdata["keys"].asInt ?? 0) == (Glob.shared["hof"].asInt ?? 0) {
      sprite(spriteNum).loc = Point(x: 1000, y: 1000)
    } else {
      sprite(spriteNum).loc = Point(x: 487, y: 220)
    }
  }
}
