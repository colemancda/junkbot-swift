// Translated from Lingo: behavior_game_interface_buttons.ls

class BehaviorGameInterfaceButtons {
    var my: Any? = nil
    var myName: String = ""
    var spriteNum: Int = 0

    func beginSprite() {
        my = sprite(spriteNum)
        myName = (my as AnyObject).member.name as! String
    }

    func mouseUp() {
        switch myName {
        case "restart_level":
            gbutton("main_play")
        case "mainmenu":
            (glob["PLAYER"] as AnyObject).game_manager.exitGame()
            go("levels")
        case "fail_tryAgain":
            gbutton("main_play")
        case "gotohelp":
            (glob["PLAYER"] as AnyObject).game_manager.exitGame()
            go("help")
        default:
            break
        }
    }

    func mouseDown() {
        SndSFX("h_button1")
        sendAllSprites("getOut")
    }

    func mouseEnter() {
        (my as AnyObject).member = member(myName + "_x")
    }

    func mouseLeave() {
        (my as AnyObject).member = member(myName)
    }
}
