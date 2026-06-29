// Translated from Lingo: behavior_21.ls

class Behavior21 {
    var myText: Member? = nil
    var howmany: Int = 0

    func beginSprite(_ spriteNum: Int) {
        howmany = numberOfCastMembers(inCastLib: "levels")
        myText = sprite(spriteNum).member
        var temp = ""
        for n in 1...max(1, howmany) {
            temp += (member(n, "levels")?.name ?? "") + "\n"
        }
        myText?.text = temp
    }

    func mouseUp() {
        let whichLevel = mouseLine
        if whichLevel > howmany { return }
        var levelList = [String]()
        for n in whichLevel...howmany {
            levelList.append(member(n, "levels")?.text ?? "")
        }
        glob.PLAYER.game_manager.setGame(levelList)
        glob.PLAYER.game_manager.startGame()
    }
}
