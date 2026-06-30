// Translated from Lingo: behavior_msgBox_IntoHallOfFame.ls

class BehaviorMsgBoxIntoHallOfFame: LingoObject, @unchecked Sendable {
  var myNum: Int = 0
  var prop: PropList = PropList()
  var waiting: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   myNum = me.spriteNum
  //   glob[#master_obj] = me
  //   Prop = [:]
  //   Prop[#state] = #hide
  //   Prop[#loc] = [#Start: point(275, -220), #show: point(265, 210), #end: point(-455, 210)]
  //   Prop[#speed] = [#move1: [0, 40], #move2: [-40, 0]]
  //   glob.PLAYER[#game_manager].TotalKeys()
  // end
  // ```
  func beginSprite() {
    Glob.shared["master_obj"] = .void  // set externally as object reference
    prop = PropList()
    prop["state"] = .string("hide")
    var loc = PropList()
    loc["Start"] = .point(x: 275, y: -220)
    loc["show"] = .point(x: 265, y: 210)
    loc["end"] = .point(x: -455, y: 210)
    prop["loc"] = .propList(loc)
    var speed = PropList()
    speed["move1"] = .list(LingoList([.int(0), .int(40)]))
    speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
    prop["speed"] = .propList(speed)
    (Glob.shared["PLAYER"]).game_manager.TotalKeys()
  }

  // Original Lingo body: dropbox
  // ```lingo
  // on dropBox me
  //   building = glob[#current][#building]
  //   level = glob[#current][#level]
  //   moves = glob[#current][#moves]
  //   data = glob[#building][building][#LEVELS][level][#moves]
  //   glob.PLAYER[#game_manager].TotalKeys()
  //   if (glob[#rankdata][#keys] + 1) < glob[#hof] then
  //     glob[#award_obj].dropBox()
  //   else
  //     if glob[#rankdata][#AlreadySawHOF] = #YES then
  //       glob[#award_obj].dropBox()
  //     else
  //       if data > 0 then
  //         glob[#award_obj].dropBox()
  //       else
  //         if not (glob[#rankdata][#AlreadySawHOF] = #YES) then
  //           glob[#rankdata][#AlreadySawHOF] = #YES
  //           Prop[#state] = #move1
  //           setCursor(#none)
  //           me.updateScreen()
  //           me.fixLocZ()
  //         end if
  //       end if
  //     end if
  //   end if
  // end
  // ```
  func dropBox() {
    let current = Glob.shared["current"].asPropList!
    let building = current["building"].asInt!
    let level = current["level"].asInt!
    let buildingList = Glob.shared["building"].asList!
    let buildingEntry = buildingList[building].asPropList!
    let levels = buildingEntry["LEVELS"].asList!
    let data = levels[level].asPropList!
    (Glob.shared["PLAYER"]).game_manager.TotalKeys()
    let rankdata = Glob.shared["rankdata"].asPropList!
    let rankKeys = rankdata["keys"].asInt!
    let hof = Glob.shared["hof"].asInt!
    if (rankKeys + 1) < hof {
      (Glob.shared["award_obj"]).dropBox()
    } else {
      if rankdata["AlreadySawHOF"].asString == "YES" {
        (Glob.shared["award_obj"]).dropBox()
      } else {
        if (data["moves"].asInt ?? 0) > 0 {
          (Glob.shared["award_obj"]).dropBox()
        } else {
          if !(rankdata["AlreadySawHOF"].asString == "YES") {
            let rankdataMut = Glob.shared["rankdata"].asPropList!
            rankdataMut["AlreadySawHOF"] = .string("YES")
            prop["state"] = .string("move1")
            setCursor("none")
            updateScreen()
            fixLocZ()
          }
        }
      }
    }
  }

  // Original Lingo body: updatescreen
  // ```lingo
  // on updateScreen me
  //   member("total.moves").text = string(glob[#rankdata][#moves])
  //   if glob[#rankdata][#serverState] = #READY then
  //     barwidth = 125
  //     rank = glob[#rankdata][#rank]
  //     total = glob[#rankdata][#players]
  //     if rank = 0 then
  //       mybar = barwidth
  //     else
  //       ratio = total / rank
  //       mybar = barwidth - (barwidth / ratio)
  //     end if
  //     sprite(myNum + 1).width = mybar
  //     member("rank_box1").text = string(glob[#rankdata][#rank])
  //     member("rank_box2").text = "out of " & string(glob[#rankdata][#players])
  //   else
  //     member("rank_box1").text = "processing"
  //     member("rank_box2").text = EMPTY
  //   end if
  // end
  // ```
  func updateScreen() {
    let rankdata = Glob.shared["rankdata"].asPropList!
    member("total.moves")?.text = String(rankdata["moves"].asInt!)
    if rankdata["serverState"].asString == "READY" {
      let barwidth = 125
      let rank = rankdata["rank"].asInt!
      let total = rankdata["players"].asInt!
      let mybar: Int
      if rank == 0 {
        mybar = barwidth
      } else {
        let ratio = Double(total) / Double(rank)
        mybar = barwidth - Int(Double(barwidth) / ratio)
      }
      sprite(myNum + 1).width = mybar
      member("rank_box1")?.text = String(rank)
      member("rank_box2")?.text = "out of \(total)"
    } else {
      member("rank_box1")?.text = "processing"
      member("rank_box2")?.text = ""
    }
  }

  // Original Lingo body: exitframe
  // ```lingo
  // on exitFrame me
  //   case glob[#master_obj].Prop[#state] of
  //     #hide:
  //     #move1:
  //       temp = me.doMove(Prop[#loc][#show], Prop[#speed][#move1])
  //       if temp = 1 then
  //         glob[#master_obj].Prop[#state] = #show
  //         waiting = the timer
  //       end if
  //     #show:
  //       setCursor(#none)
  //       me.updateScreen()
  //       if the timer > (waiting + 300) then
  //         sprite(myNum + 3).loc = point(1000, 1000)
  //       end if
  //     #move2:
  //       temp = me.doMove(Prop[#loc][#end], Prop[#speed][#move2])
  //       if temp then
  //         glob[#master_obj].Prop[#state] = #done
  //         me.updateLoc(Prop[#loc][#Start])
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
      if temp == 1 {
        prop["state"] = .string("show")
        waiting = currentTicks
      }
    case "show":
      setCursor("none")
      updateScreen()
      if currentTicks > (waiting + 300) {
        sprite(myNum + 3).loc = Point(x: 1000, y: 1000)
      }
    case "move2":
      let locEnd = prop["loc"]["end"].asPoint!
      let speedList = prop["speed"]["move2"].asList!
      let spd = [speedList[1].asInt!, speedList[2].asInt!]
      let temp = doMove(toWhere: locEnd, speed: spd)
      if temp != 0 {
        prop["state"] = .string("done")
        updateLoc(newloc: prop["loc"]["Start"].asPoint!)
      }
    default:
      break
    }
  }

  @discardableResult
  // Original Lingo body: domove
  // ```lingo
  // on doMove me, toWhere, speed
  //   case glob[#master_obj].Prop[#state] of
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

  // Original Lingo body: reportstate
  // ```lingo
  // on reportState me
  //   return Prop[#state]
  // end
  // ```
  func reportState() -> String {
    return prop["state"].asString!
  }

  // Original Lingo body: updateloc
  // ```lingo
  // on updateLoc me, newloc
  //   sprite(myNum).loc = newloc
  //   sprite(myNum + 1).loc = sprite(myNum).loc + point(-189, 125)
  //   sprite(myNum + 2).loc = sprite(myNum).loc + point(146, 150)
  //   if not (glob[#master_obj].Prop[#state] = #move2) then
  //     sprite(myNum + 3).loc = sprite(myNum).loc + point(0, -1)
  //   end if
  // end
  // ```
  func updateLoc(newloc: Point) {
    sprite(myNum).loc = newloc
    sprite(myNum + 1).loc = sprite(myNum).loc + Point(x: -189, y: 125)
    sprite(myNum + 2).loc = sprite(myNum).loc + Point(x: 146, y: 150)
    if !(prop["state"].asString == "move2") {
      sprite(myNum + 3).loc = sprite(myNum).loc + Point(x: 0, y: -1)
    }
  }

  // Original Lingo body: fixlocz
  // ```lingo
  // on fixLocZ me
  //   sprite(myNum).locZ = 1000000000
  //   sprite(myNum + 1).locZ = 1000000001
  //   sprite(myNum + 2).locZ = 1000000001
  //   sprite(myNum + 3).locZ = 1000000002
  // end
  // ```
  func fixLocZ() {
    sprite(myNum).locZ = 1_000_000_000
    sprite(myNum + 1).locZ = 1_000_000_001
    sprite(myNum + 2).locZ = 1_000_000_001
    sprite(myNum + 3).locZ = 1_000_000_002
  }
}
