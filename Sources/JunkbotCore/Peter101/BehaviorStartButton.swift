// Translated from Lingo: behavior_STARTBUTTON.ls

class BehaviorStartButton: LingoObject, @unchecked Sendable {
  var my: LingoSprite? = nil
  var myName: String = ""
  var spriteNum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   my = sprite(me.spriteNum)
  //   myName = my.member.name
  //   my.blend = 100
  // end
  // ```
  func beginSprite() {
    my = sprite(spriteNum)
    myName = my?.member?.name ?? ""
    my?.blend = 100
  }

  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   if not (glob[#memo] = #DidIt) then
  //     glob[#memo] = #show
  //   end if
  //   my.member = member(myName)
  //   SndMusicEnd()
  //   go("levels")
  // end
  // ```
  func mouseUp() {
    if !(Glob.shared["memo"].asString == "DidIt") {
      Glob.shared["memo"] = .string("show")
    }
    my?.member = member(myName)
    SndMusicEnd()
    go("levels")
  }

  // Original Lingo body: mousedown
  // ```lingo
  // on mouseDown me
  //   SndSFX("h_button1")
  // end
  // ```
  func mouseDown() {
    SndSFX("h_button1")
  }

  // Original Lingo body: mousewithin
  // ```lingo
  // on mouseWithin me
  //   my.member = member(myName & "_ro")
  // end
  // ```
  func mouseWithin() {
    my?.member = member(myName + "_ro")
  }

  // Original Lingo body: mouseleave
  // ```lingo
  // on mouseLeave me
  //   my.member = member(myName)
  // end
  // ```
  func mouseLeave() {
    my?.member = member(myName)
  }
}
