// Translated from Lingo: behavior_msgBox_HINT.ls

class BehaviorMsgBoxHint: LingoObject, @unchecked Sendable {
  var prop: PropList = PropList()
  var myNum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   myNum = me.spriteNum
  //   glob[#hint_obj] = me
  //   Prop = [:]
  //   Prop[#state] = #hide
  //   Prop[#loc] = [#Start: point(275, -125), #show: point(275, 215), #end: point(-195, 215)]
  //   Prop[#speed] = [#move1: [0, 40], #move2: [-40, 0]]
  // end
  // ```
  func beginSprite() {
    Glob.shared["hint_obj"] = .void  // set externally as object reference
    prop = PropList()
    prop["state"] = .string("hide")
    var loc = PropList()
    loc["Start"] = .point(x: 275, y: -125)
    loc["show"] = .point(x: 275, y: 215)
    loc["end"] = .point(x: -195, y: 215)
    prop["loc"] = .propList(loc)
    var speed = PropList()
    speed["move1"] = .list(LingoList([.int(0), .int(40)]))
    speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
    prop["speed"] = .propList(speed)
  }

  // Original Lingo body: dropbox
  // ```lingo
  // on dropBox me
  //   building = glob[#current][#building]
  //   level = glob[#current][#level]
  //   hint = glob.building[building].LEVELS[level].info.hint
  //   member("hint_text").text = "level " & level & " hint:" & RETURN & hint
  //   Prop[#state] = #move1
  //   Prop[#gameState] = glob.PLAYER.play_manager.activeState
  //   glob.PLAYER.play_manager.activeState = #pause
  // end
  // ```
  func dropBox() {
    let current = Glob.shared["current"].asPropList!
    let building = current["building"].asInt!
    let level = current["level"].asInt!
    let hint: String =
      (Glob.shared["building"]).building(.int(building)).LEVELS(.int(level)).info.hint.asString
      ?? ""
    member("hint_text")?.text = "level \(level) hint:\n\(hint)"
    prop["state"] = .string("move1")
    prop["gameState"] = (Glob.shared["PLAYER"]).play_manager.activeState
    (Glob.shared["PLAYER"]).play_manager.activeState = "pause"
  }

  // Original Lingo body: updatestate
  // ```lingo
  // on updateState me, state
  //   Prop[#state] = state
  // end
  // ```
  func updateState(_ state: String) {
    prop["state"] = .string(state)
  }

  // Original Lingo body: reportstate
  // ```lingo
  // on reportState me
  //   return Prop[#state]
  // end
  // ```
  func reportState() -> String {
    return prop["state"].asString!
  }

  // Original Lingo body: exitframe
  // ```lingo
  // on exitFrame me
  //   case Prop[#state] of
  //     #hide:
  //     #move1:
  //       temp = me.doMove(Prop[#loc][#show], Prop[#speed][#move1])
  //       if temp then
  //         Prop[#state] = #show
  //       end if
  //     #show:
  //       setCursor(#none)
  //     #move2:
  //       temp = me.doMove(Prop[#loc][#end], Prop[#speed][#move2])
  //       if temp then
  //         Prop[#state] = #done
  //         me.updateLoc(Prop[#loc][#Start])
  //         if Prop[#gameState] = #pause then
  //           gbutton(#main_play)
  //         else
  //           glob.PLAYER.play_manager.activeState = #Run
  //         end if
  //       end if
  //   end case
  // end
  // ```
  func exitFrame() {
    switch prop["state"].asString! {
    case "hide":
      break
    case "move1":
      let locShow = prop["loc"]["show"].asPoint!
      let speedList = prop["speed"]["move1"].asList!
      let spd = [speedList[1].asInt!, speedList[2].asInt!]
      let temp = doMove(toWhere: locShow, speed: spd)
      if temp != 0 {
        prop["state"] = .string("show")
      }
    case "show":
      setCursor("none")
    case "move2":
      let locEnd = prop["loc"]["end"].asPoint!
      let speedList = prop["speed"]["move2"].asList!
      let spd = [speedList[1].asInt!, speedList[2].asInt!]
      let temp = doMove(toWhere: locEnd, speed: spd)
      if temp != 0 {
        prop["state"] = .string("done")
        updateLoc(newloc: prop["loc"]["Start"].asPoint!)
        if prop["gameState"].asString == "pause" {
          gbutton("main_play")
        } else {
          (Glob.shared["PLAYER"]).play_manager.activeState = "Run"
        }
      }
    default:
      break
    }
  }

  @discardableResult
  // Original Lingo body: domove
  // ```lingo
  // on doMove me, toWhere, speed
  //   case Prop[#state] of
  //     #move1:
  //       if sprite(myNum).locV < toWhere[2] then
  //         newloc = sprite(myNum).loc + point(speed[1], speed[2])
  //         me.updateLoc(newloc)
  //         return 0
  //       else
  //         return 1
  //       end if
  //     #move2:
  //       if sprite(myNum).locH > toWhere[1] then
  //         newloc = sprite(myNum).loc + point(speed[1], speed[2])
  //         me.updateLoc(newloc)
  //         return 0
  //       else
  //         return 1
  //       end if
  //   end case
  // end
  // ```
  func doMove(toWhere: Point, speed: [Int]) -> Int {
    switch prop["state"].asString! {
    case "move1":
      if sprite(myNum).loc.y < toWhere.y {
        let newloc = sprite(myNum).loc + Point(x: speed[0], y: speed[1])
        updateLoc(newloc: newloc)
        return 0
      } else {
        return 1
      }
    case "move2":
      if sprite(myNum).loc.x > toWhere.x {
        let newloc = sprite(myNum).loc + Point(x: speed[0], y: speed[1])
        updateLoc(newloc: newloc)
        return 0
      } else {
        return 1
      }
    default:
      return 0
    }
  }

  // Original Lingo body: updateloc
  // ```lingo
  // on updateLoc me, newloc
  //   sprite(myNum).loc = newloc
  //   sprite(myNum + 1).loc = sprite(myNum).loc + point(0, 53)
  //   sprite(myNum + 2).loc = sprite(myNum).loc + point(-139, -83)
  // end
  // ```
  func updateLoc(newloc: Point) {
    sprite(myNum).loc = newloc
    sprite(myNum + 1).loc = sprite(myNum).loc + Point(x: 0, y: 53)
    sprite(myNum + 2).loc = sprite(myNum).loc + Point(x: -139, y: -83)
  }

  // Original Lingo body: fixlocz
  // ```lingo
  // on fixLocZ me
  // end
  // ```
  func fixLocZ() {
    // no-op
  }

  // Original Lingo body: mouseup
  // ```lingo
  // on mouseUp me
  //   Prop[#state] = #move2
  // end
  // ```
  func mouseUp() {
    prop["state"] = .string("move2")
  }

  // Original Lingo body: getout
  // ```lingo
  // on getOut me
  //   if Prop[#state] = #show then
  //     Prop[#state] = #move2
  //   end if
  // end
  // ```
  func getOut() {
    if prop["state"].asString == "show" {
      prop["state"] = .string("move2")
    }
  }
}
