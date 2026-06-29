// Translated from Lingo: behavior_game_interface_buttons.ls

class BehaviorGameInterfaceButtons: BehaviorBase {
    var my: LV = .void       // the sprite
    var myName: String = ""

    var spriteNum: Int = 0

    func beginSprite() {
        // my = sprite(spriteNum)
        // myName = my.member.name
    }

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

    func mouseDown() {
        SndSFX("h_button1")
        // sendAllSprites(#getOut)
    }

    func mouseEnter() {
        // my.member = member(myName + "_x")
    }

    func mouseLeave() {
        // my.member = member(myName)
    }
}
