// Translated from Lingo: behavior_sign register behavior.ls

class BehaviorSignRegister: LingoObject, @unchecked Sendable {
  var my: Sprite?
  var who: String? = nil

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   my = sprite(me.spriteNum)
  //   my.blend = 0
  //   glob.PLAYER[#signsprite] = my
  // end
  // ```
  func beginSprite(_ spriteNum: Int) {
    my = sprite(spriteNum)
    my?.blend = 0
    if let spr = my { glob.PLAYER["signsprite"] = .object(spr) }
  }

  // Original Lingo body: showsign
  // ```lingo
  // on showSign me, memName, pram
  //   who = pram
  //   my.member = member(memName)
  //   my.blend = 100
  //   my.locZ = 10000000
  // end
  // ```
  func showSign(_ memName: String, pram: String) {
    who = pram
    my?.member = member(memName)
    my?.blend = 100
    my?.locZ = 10_000_000
  }

  // Original Lingo body: hidesign
  // ```lingo
  // on hideSign me
  //   my.blend = 0
  // end
  // ```
  func hideSign() {
    my?.blend = 0
  }

  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   case who of
  //     #gameOverButton:
  //       gbutton(#main_play)
  //     #goNextLevelButton:
  //       glob.PLAYER.game_manager.goNextLevelButton()
  //   end case
  //   hideSign(me)
  // end
  // ```
  func mouseUp() {
    switch who {
    case "gameOverButton":
      gbutton("main_play")
    case "goNextLevelButton":
      glob.PLAYER.game_manager.goNextLevelButton()
    default:
      break
    }
    hideSign()
  }
}
