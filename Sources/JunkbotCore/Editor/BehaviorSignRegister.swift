// Translated from Lingo: behavior_sign register behavior.ls

class BehaviorSignRegister {
    var my: Sprite?
    var who: String? = nil

    func beginSprite(_ spriteNum: Int) {
        my = sprite(spriteNum)
        my?.blend = 0
        glob.PLAYER["signsprite"] = my
    }

    func showSign(_ memName: String, pram: String) {
        who = pram
        my?.member = member(memName)
        my?.blend = 100
        my?.locZ = 10000000
    }

    func hideSign() {
        my?.blend = 0
    }

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
