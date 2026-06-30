// Translated from Lingo: behavior_21.ls

class Behavior21: LingoObject, @unchecked Sendable {
  var myText: Member? = nil
  var howmany: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   howmany = the number of castMembers of castLib "levels"
  //   myText = sprite(me.spriteNum).member
  //   temp = EMPTY
  //   repeat with n = 1 to howmany
  //     temp = temp & member(n, "levels").name & RETURN
  //   end repeat
  //   myText.text = temp
  // end
  // ```
  func beginSprite(_ spriteNum: Int) {
    howmany = numberOfCastMembers(inCastLib: "levels")
    myText = sprite(spriteNum).member
    var temp = ""
    for n in 1...max(1, howmany) {
      temp += (member(n, "levels")?.name ?? "") + "\n"
    }
    myText?.text = temp
  }

  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   whichLevel = the mouseLine
  //   if whichLevel > howmany then
  //     return
  //   else
  //     levelList = []
  //     repeat with n = whichLevel to howmany
  //       levelList.add(member(n, "levels").text)
  //     end repeat
  //     glob.PLAYER.game_manager.setGame(levelList)
  //     glob.PLAYER.game_manager.startGame()
  //   end if
  // end
  // ```
  func mouseUp() {
    let whichLevel = mouseLine
    if whichLevel > howmany { return }
    var levelList = [String]()
    for n in whichLevel...howmany {
      levelList.append(member(n, "levels")?.text ?? "")
    }
    glob.PLAYER.game_manager.setGame(.list(LingoList(levelList.map { .string($0) })))
    glob.PLAYER.game_manager.startGame()
  }
}
