// Translated from Lingo: behavior_game_interface_buttons.ls

class BehaviorGameInterfaceButtons: LingoObject, @unchecked Sendable {
    var my: LV = .void       // the sprite
    var myName: String = ""

    var spriteNum: Int = 0

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   my = sprite(me.spriteNum)
    //   myName = my.member.name
    // end
    // ```
    func beginSprite() {
        // my = sprite(spriteNum)
        // myName = my.member.name
    }

    // Original Lingo body: mouseup
    // ```lingo
    // on mouseUp me
    //   case myName of
    //     "restart_level":
    //       gbutton(#main_play)
    //     "mainmenu":
    //       glob.PLAYER.game_manager.exitGame()
    //       go("levels")
    //     "fail_tryAgain":
    //       gbutton(#main_play)
    //     "gotohelp":
    //       glob.PLAYER.game_manager.exitGame()
    //       go("help")
    //   end case
    // end
    // ```
    func mouseUp() {
        switch myName {
        case "restart_level":
            gbutton("main_play")
        case "mainmenu":
            // Glob.shared["PLAYER"].asPropList?.game_manager.exitGame()
            go("levels")
        case "fail_tryAgain":
            gbutton("main_play")
        default:
            break
        }
    }

    // Original Lingo body: mousedown
    // ```lingo
    // on mouseDown me
    //   SndSFX("h_button1")
    //   sendAllSprites(#getOut)
    // end
    // ```
    func mouseDown() {
        SndSFX("h_button1")
        // sendAllSprites(#getOut)
    }

    // Original Lingo body: mouseenter
    // ```lingo
    // on mouseEnter me
    //   my.member = member(myName & "_x")
    // end
    // ```
    func mouseEnter() {
        // my.member = member(myName + "_x")
    }

    // Original Lingo body: mouseleave
    // ```lingo
    // on mouseLeave me
    //   my.member = member(myName)
    // end
    // ```
    func mouseLeave() {
        // my.member = member(myName)
    }
}
