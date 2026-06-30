// Translated from Lingo: behavior_UpdateTotalMoves.ls

class BehaviorUpdateTotalMoves: LingoObject, @unchecked Sendable {
  var spriteNum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   if glob[#rankdata][#keys] < glob[#hof] then
  //     exit
  //   end if
  //   sprite(me.spriteNum).member.text = string(glob[#rankdata][#moves])
  // end
  // ```
  func beginSprite() {
    let rankdata = Glob.shared["rankdata"].asPropList!
    if (rankdata["keys"].asInt ?? 0) < (Glob.shared["hof"].asInt ?? 0) {
      return
    }
    sprite(spriteNum).member?.text = String(Glob.shared["rankdata"]["moves"].asInt!)
  }
}
