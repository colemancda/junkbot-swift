// Translated from Lingo: behavior_self-update_portrait.ls

class BehaviorSelfUpdatePortrait: LingoObject, @unchecked Sendable {
  var spriteNum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   if glob[#rankdata][#keys] < glob[#hof] then
  //     sprite(me.spriteNum).member = member("portrait_1")
  //     sprite(me.spriteNum).width = 148
  //     sprite(me.spriteNum).height = 130
  //     sprite(me.spriteNum).loc = point(566, 88)
  //   else
  //     sprite(me.spriteNum).member = member("portrait_2")
  //     sprite(me.spriteNum).width = 135
  //     sprite(me.spriteNum).height = 120
  //     sprite(me.spriteNum).loc = point(560, 83)
  //   end if
  // end
  // ```
  func beginSprite() {
    let rankdata = Glob.shared["rankdata"].asPropList!
    let hof = Glob.shared["hof"].asInt!
    if (rankdata["keys"].asInt ?? 0) < hof {
      sprite(spriteNum).member = member("portrait_1")
      sprite(spriteNum).width = 148
      sprite(spriteNum).height = 130
      sprite(spriteNum).loc = Point(x: 566, y: 88)
    } else {
      sprite(spriteNum).member = member("portrait_2")
      sprite(spriteNum).width = 135
      sprite(spriteNum).height = 120
      sprite(spriteNum).loc = Point(x: 560, y: 83)
    }
  }
}
