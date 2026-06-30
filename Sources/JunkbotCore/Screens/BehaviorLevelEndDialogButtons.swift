// Translated from Lingo: behavior_level end dialog buttons behavior.ls

class BehaviorLevelEndDialogButtons: LingoObject, @unchecked Sendable {
  var which: String = "none"
  var spriteNum: Int = 0

  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   if sprite(me.spriteNum).blend = 0 then
  //     exit
  //   end if
  //   case which of
  //     #com_nextlevel:
  //       level = glob[#current][#level]
  //       building = glob[#current][#building]
  //       if (level = 15) and not (building = 4) then
  //         lock = glob[#building][building + 1][#state]
  //         if lock = #open then
  //           glob[#current][#building] = glob[#current][#building] + 1
  //         end if
  //       end if
  //       glob.BIG_MSG_OBJ.updateState(#move2, [#object: glob.PLAYER.game_manager, #parameter: #com_nextlevel])
  //     #com_selectlevel:
  //       glob.BIG_MSG_OBJ.updateState(#move2, [#object: glob.PLAYER.game_manager, #parameter: #select_level])
  //     #fail_tryagain:
  //       glob.fail_msg_obj.updateState(#move2, [#object: glob.PLAYER.game_manager, #parameter: #restart_level])
  //     #fail_gethint:
  //       glob[#hint_obj].updateState(#move2)
  //     #fail_selectlevel:
  //       glob.fail_msg_obj.updateState(#move2, [#object: glob.PLAYER.game_manager, #parameter: #select_level])
  //   end case
  // end
  // ```
  func mouseUp() {
    if sprite(spriteNum).blend == 0 {
      return
    }
    switch which {
    case "com_nextlevel":
      let current = Glob.shared["current"].asPropList!
      let level = current["level"].asInt!
      let building = current["building"].asInt!
      if (level == 15) && !(building == 4) {
        let buildingList = Glob.shared["building"].asList!
        let lock = buildingList[building + 1]["state"].asString!
        if lock == "open" {
          let currentPL = Glob.shared["current"].asPropList!
          currentPL["building"] = .int(building + 1)
        }
      }
      (Glob.shared["BIG_MSG_OBJ"]).updateState(
        "move2", ["object": (Glob.shared["PLAYER"]).game_manager, "parameter": "com_nextlevel"])
    case "com_selectlevel":
      (Glob.shared["BIG_MSG_OBJ"]).updateState(
        "move2", ["object": (Glob.shared["PLAYER"]).game_manager, "parameter": "select_level"])
    case "fail_tryagain":
      (Glob.shared["fail_msg_obj"]).updateState(
        "move2", ["object": (Glob.shared["PLAYER"]).game_manager, "parameter": "restart_level"])
    case "fail_gethint":
      (Glob.shared["hint_obj"]).updateState("move2")
    case "fail_selectlevel":
      (Glob.shared["fail_msg_obj"]).updateState(
        "move2", ["object": (Glob.shared["PLAYER"]).game_manager, "parameter": "select_level"])
    default:
      break
    }
  }

  // Original Lingo body: mousedown
  // ```lingo
  // on mouseDown me
  //   if sprite(me.spriteNum).blend = 0 then
  //     exit
  //   end if
  //   SndSFX("h_button1")
  // end
  // ```
  func mouseDown() {
    if sprite(spriteNum).blend == 0 {
      return
    }
    SndSFX("h_button1")
  }

  // Property description: which is #propList with range [#com_nextlevel, #fail_tryagain, #fail_gethint, #fail_selectlevel], default #none
}
