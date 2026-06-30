// Translated from Lingo: behavior_BossMemo_script.ls

class BehaviorBossMemo: LingoObject, @unchecked Sendable {
  var snum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   glob[#boss] = me
  //   snum = me.spriteNum
  //   glob.PLAYER[#game_manager].TotalKeys()
  //   glob[#memo] = #show
  //   if glob[#rankdata][#keys] > 0 then
  //     glob[#memo] = #DidIt
  //   end if
  //   if glob[#memo] = #show then
  //     sprite(snum).loc = point(233, 209)
  //     sprite(snum + 1).loc = point(27, 23)
  //     sprite(snum + 2).loc = point(33, 104)
  //     sprite(snum + 3).loc = point(234, 354)
  //     glob[#memo] = #DidIt
  //   else
  //     me.hide()
  //   end if
  // end
  // ```
  func beginSprite() {
    Glob.shared["boss"] = .void  // set to self via object store externally
    let rankdata = Glob.shared["rankdata"].asPropList!
    if (rankdata["keys"].asInt ?? 0) > 0 {
      Glob.shared["memo"] = .string("DidIt")
    }
    if Glob.shared["memo"].asString == "show" {
      sprite(snum).loc = Point(x: 233, y: 209)
      sprite(snum + 1).loc = Point(x: 27, y: 23)
      sprite(snum + 2).loc = Point(x: 33, y: 104)
      sprite(snum + 3).loc = Point(x: 234, y: 354)
      Glob.shared["memo"] = .string("DidIt")
    } else {
      hide()
    }
  }

  // Original Lingo body: hide
  // ```lingo
  // on hide me
  //   sprite(snum).loc = point(1000, 209)
  //   sprite(snum + 1).loc = point(1000, 23)
  //   sprite(snum + 2).loc = point(1000, 104)
  //   sprite(snum + 3).loc = point(1000, 354)
  //   updateStage()
  // end
  // ```
  func hide() {
    sprite(snum).loc = Point(x: 1000, y: 209)
    sprite(snum + 1).loc = Point(x: 1000, y: 23)
    sprite(snum + 2).loc = Point(x: 1000, y: 104)
    sprite(snum + 3).loc = Point(x: 1000, y: 354)
    updateStage()
  }
}
