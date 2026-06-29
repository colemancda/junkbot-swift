// Translated from Lingo: behavior_game_interface_buttons.ls

class BehaviorGameInterfaceButtons {
    var my: Any? = nil       // the sprite
    var myName: String = ""

    // Reference to global state (injected externally)
    var glob: [String: Any] = [:]

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
            // glob.PLAYER.game_manager.exitGame()
            go(label: "levels")
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

    // Stubs
    func gbutton(_ msg: String) { /* stub — implemented in MovieMain */ }
    func SndSFX(_ sound: String) { /* stub — implemented in MovieSoundCode */ }
    func go(label: String) { /* stub */ }
}
