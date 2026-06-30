// Translated from Lingo: behavior_msgBox_Success.ls

class BehaviorMsgBoxSuccess: LingoObject, @unchecked Sendable {
  var prop: PropList = PropList()
  var myNum: Int = 0
  var keys: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   myNum = me.spriteNum
  //   glob[#BIG_MSG_OBJ] = me
  //   Prop = [:]
  //   Prop[#state] = #hide
  //   Prop[#loc] = [#Start: point(60, -280), #show: point(60, 80), #end: point(-340, 80)]
  //   Prop[#speed] = [#move1: [0, 40], #move2: [-40, 0]]
  //   Prop[#sprites] = [#MSG1: myNum + 9, #MSG2: myNum + 10, #MSG3: myNum + 11, #newrecord: myNum + 2, #gold: myNum + 3, #bicon: myNum + 4, #keys: myNum + 8]
  //   Prop[#todo] = []
  // end
  // ```
  func beginSprite() {
    Glob.shared["BIG_MSG_OBJ"] = .void  // set externally as object reference
    prop = PropList()
    prop["state"] = .string("hide")
    var loc = PropList()
    loc["Start"] = .point(x: 60, y: -280)
    loc["show"] = .point(x: 60, y: 80)
    loc["end"] = .point(x: -340, y: 80)
    prop["loc"] = .propList(loc)
    var speed = PropList()
    speed["move1"] = .list(LingoList([.int(0), .int(40)]))
    speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
    prop["speed"] = .propList(speed)
    var sprites = PropList()
    sprites["MSG1"] = .int(myNum + 9)
    sprites["MSG2"] = .int(myNum + 10)
    sprites["MSG3"] = .int(myNum + 11)
    sprites["newrecord"] = .int(myNum + 2)
    sprites["gold"] = .int(myNum + 3)
    sprites["bicon"] = .int(myNum + 4)
    sprites["keys"] = .int(myNum + 8)
    prop["sprites"] = .propList(sprites)
    prop["todo"] = .list(LingoList())
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

  // Original Lingo body: dropbox
  // ```lingo
  // on dropBox me
  //   setCursor(#none)
  //   sendAllSprites(#getOut)
  //   Prop[#state] = #move1
  //   me.fixLocZ()
  //   me.updateData1()
  // end
  // ```
  func dropBox() {
    setCursor("none")
    sendAllSprites("getOut")
    prop["state"] = .string("move1")
    fixLocZ()
    updateData1()
  }

  // Original Lingo body: updatedata1
  // ```lingo
  // on updateData1 me
  //   Prop[#todo] = []
  //   building = glob[#current][#building]
  //   level = glob[#current][#level]
  //   moves = glob[#current][#moves]
  //   gold = glob[#building][building][#LEVELS][level][#gold]
  //   if level > 15 then
  //     exit
  //   end if
  //   repeat with x = 1 to 4
  //     if glob[#building][x][#state] = #open then
  //       sprite(x + (Prop[#sprites][#bicon] - 1)).member = member("building_icon_" & x)
  //       updateStage()
  //     end if
  //   end repeat
  //   member("num.moves").text = string(moves)
  //   flag = 0
  //   sprite(Prop[#sprites][#newrecord]).blend = 0
  //   data = glob[#building][building][#LEVELS]
  //   keys = 0
  //   repeat with i = 1 to 15
  //     if i = level then
  //       if data[i][#moves] > 0 then
  //         member("msgbox_1").text = "KEYCARD ALREADY ACQUIRED"
  //         sprite(myNum + 15).blend = 0
  //       else
  //         member("msgbox_1").text = "YOU GOT A BUILDING " & building & " KEYCARD"
  //         sprite(myNum + 15).blend = 100
  //         data[i][#moves] = moves
  //       end if
  //       if moves < data[i][#moves] then
  //         Prop[#todo].add(#newrecord)
  //         sprite(Prop[#sprites][#newrecord]).blend = 100
  //         data[i][#moves] = moves
  //       end if
  //       if gold = 1 then
  //         sprite(Prop[#sprites][#gold]).blend = 100
  //         member("msgbox_3").text = EMPTY
  //       else
  //         if data[i][#moves] <= data[i][#goal] then
  //           glob[#building][building][#LEVELS][level][#gold] = 1
  //           Prop[#todo].add(#goldaward)
  //           sprite(Prop[#sprites][#gold]).blend = 100
  //           member("msgbox_3").text = EMPTY
  //         else
  //           member("msgbox_3").text = "beat this level in " & data[i][#goal] & " moves or fewer" & RETURN & "to get the gold award"
  //           sprite(Prop[#sprites][#gold]).blend = 0
  //         end if
  //       end if
  //     end if
  //     if data[i][#moves] > 0 then
  //       keys = keys + 1
  //     end if
  //   end repeat
  //   if (keys >= glob[#keyrequired]) and not (building = 4) and not (glob[#building][building + 1][#state] = #open) then
  //     member("msgbox_2").text = "YOU UNLOCKED BUILDING " & building + 1
  //     Prop[#todo].add(#unlock)
  //     glob[#building][building + 1][#state] = #open
  //     SndSFX("unlock2")
  //   else
  //     if keys >= glob[#keyrequired] then
  //       glob.PLAYER[#game_manager].TotalKeys()
  //       if glob[#rankdata][#keys] = 60 then
  //         member("msgbox_2").text = EMPTY
  //       else
  //         member("msgbox_2").text = "GET ALL THE KEYCARDS!"
  //       end if
  //     else
  //       if (keys < glob[#keyrequired]) and not (building = 4) then
  //         member("msgbox_2").text = "GET " & glob[#keyrequired] - keys & " MORE TO UNLOCK BUILDING " & building + 1
  //       else
  //         member("msgbox_2").text = EMPTY
  //       end if
  //     end if
  //   end if
  //   if (level = 15) and (keys >= glob[#keyrequired]) and not (glob[#current][#building] = 4) then
  //     sprite(myNum + 13).blend = 100
  //     sprite(myNum + 13).member = member("but_next_bd")
  //     updateStage()
  //     sprite(myNum + 13).updateProp()
  //   else
  //     if (level = 15) and (keys >= glob[#keyrequired]) and (glob[#current][#building] = 4) then
  //       sprite(myNum + 13).blend = 0
  //     else
  //       sprite(myNum + 13).blend = 100
  //     end if
  //   end if
  //   me.makekey(keys)
  // end
  // ```
  func updateData1() {
    prop["todo"] = .list(LingoList())
    let current = Glob.shared["current"].asPropList!
    let building = current["building"].asInt!
    let level = current["level"].asInt!
    let moves = current["moves"].asInt!
    let buildingList = Glob.shared["building"].asList!
    let buildingEntry = buildingList[building].asPropList!
    let levelsLV = buildingEntry["LEVELS"]
    let levelsList = levelsLV.asList!
    let gold = levelsList[level]["gold"].asInt!
    if level > 15 {
      return
    }
    let sprites = prop["sprites"].asPropList!
    for x in 1...4 {
      let bEntry = buildingList[x].asPropList!
      let buildingState = bEntry["state"].asString!
      if buildingState == "open" {
        sprite(x + (sprites["bicon"].asInt! - 1)).member = member("building_icon_\(x)")
        updateStage()
      }
    }
    member("num.moves")?.text = String(moves)
    sprite(sprites["newrecord"].asInt!).blend = 0
    let data = levelsList
    keys = 0
    for i in 1...15 {
      let dataEntry = data[i].asPropList!
      if i == level {
        if (dataEntry["moves"].asInt ?? 0) > 0 {
          member("msgbox_1")?.text = "KEYCARD ALREADY ACQUIRED"
          sprite(myNum + 15).blend = 0
        } else {
          member("msgbox_1")?.text = "YOU GOT A BUILDING \(building) KEYCARD"
          sprite(myNum + 15).blend = 100
          dataEntry["moves"] = .int(moves)
        }
        if moves < (dataEntry["moves"].asInt ?? 0) {
          let todo = prop["todo"].asList!
          todo.add(.string("newrecord"))
          sprite(sprites["newrecord"].asInt!).blend = 100
          dataEntry["moves"] = .int(moves)
        }
        if gold == 1 {
          sprite(sprites["gold"].asInt!).blend = 100
          member("msgbox_3")?.text = ""
        } else {
          if (dataEntry["moves"].asInt ?? 0) <= (dataEntry["goal"].asInt ?? 0) {
            buildingEntry["LEVELS"].asList![level]["gold"] = .int(1)
            let todo = prop["todo"].asList!
            todo.add(.string("goldaward"))
            sprite(sprites["gold"].asInt!).blend = 100
            member("msgbox_3")?.text = ""
          } else {
            member("msgbox_3")?.text =
              "beat this level in \(dataEntry["goal"].asInt!) moves or fewer\nto get the gold award"
            sprite(sprites["gold"].asInt!).blend = 0
          }
        }
      }
      if (dataEntry["moves"].asInt ?? 0) > 0 {
        keys += 1
      }
    }
    let keyrequired = Glob.shared["keyrequired"].asInt!
    if (keys >= keyrequired) && !(building == 4)
      && !(buildingList[building + 1]["state"].asString == "open")
    {
      member("msgbox_2")?.text = "YOU UNLOCKED BUILDING \(building + 1)"
      let todo = prop["todo"].asList!
      todo.add(.string("unlock"))
      buildingList[building + 1]["state"] = .string("open")
      SndSFX("unlock2")
    } else {
      if keys >= keyrequired {
        (Glob.shared["PLAYER"]).game_manager.TotalKeys()
        let rankdata = Glob.shared["rankdata"].asPropList!
        if (rankdata["keys"].asInt ?? 0) == 60 {
          member("msgbox_2")?.text = ""
        } else {
          member("msgbox_2")?.text = "GET ALL THE KEYCARDS!"
        }
      } else {
        if (keys < keyrequired) && !(building == 4) {
          member("msgbox_2")?.text =
            "GET \(keyrequired - keys) MORE TO UNLOCK BUILDING \(building + 1)"
        } else {
          member("msgbox_2")?.text = ""
        }
      }
    }
    if (level == 15) && (keys >= keyrequired) && !(current["building"].asInt == 4) {
      sprite(myNum + 13).blend = 100
      sprite(myNum + 13).member = member("but_next_bd")
      updateStage()
      sprite(myNum + 13).updateProp()
    } else {
      if (level == 15) && (keys >= keyrequired) && (current["building"].asInt == 4) {
        sprite(myNum + 13).blend = 0
      } else {
        sprite(myNum + 13).blend = 100
      }
    }
    makekey(keys: keys)
  }

  // Original Lingo body: exitframe
  // ```lingo
  // on exitFrame me
  //   building = glob[#current][#building]
  //   case Prop[#state] of
  //     #hide:
  //     #move1:
  //       temp = me.doMove(Prop[#loc][#show], Prop[#speed][#move1])
  //       if temp then
  //         Prop[#state] = #show
  //       end if
  //     #show:
  //       setCursor(#none)
  //       if getOne(Prop[#todo], #unlock) > 0 then
  //         if building < 4 then
  //           bsp = sprite(Prop[#sprites][#bicon] + building)
  //           repeat with n = 1 to 10
  //             bsp.rect = bsp.rect + rect(-1, -1, 1, 1)
  //             bsp.blend = bsp.blend - 5
  //             updateStage()
  //           end repeat
  //           repeat with n = 1 to 10
  //             bsp.rect = bsp.rect + rect(1, 1, -1, -1)
  //             bsp.blend = bsp.blend + 5
  //             updateStage()
  //           end repeat
  //           bsp.stretch = 0
  //           updateStage()
  //           bsp.member = member("building_icon_" & building + 1)
  //         end if
  //       end if
  //       if getOne(Prop[#todo], #goldaward) > 0 then
  //         bsp = sprite(Prop[#sprites][#gold])
  //         bsp.blend = 100
  //         updateStage()
  //       end if
  //       if getOne(Prop[#todo], #newrecord) > 0 then
  //         bsp = sprite(Prop[#sprites][#newrecord])
  //         bsp.blend = 100
  //         updateStage()
  //       end if
  //       Prop[#state] = #showdone
  //     #move2:
  //       temp = me.doMove(Prop[#loc][#end], Prop[#speed][#move2])
  //       if temp then
  //         Prop[#state] = #hide
  //         me.updateLoc(Prop[#loc][#Start])
  //         if not voidp(Prop[#callback]) then
  //           Prop.callback.object.callback(Prop.callback.parameter)
  //           Prop.callback = VOID
  //         end if
  //       end if
  //   end case
  // end
  // ```
  func exitFrame() {
    let current = Glob.shared["current"].asPropList!
    let building = current["building"].asInt!
    let sprites = prop["sprites"].asPropList!
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
      let todo = prop["todo"].asList!
      if todo.getOne(.string("unlock")) {
        if building < 4 {
          let bsp = sprite(sprites["bicon"].asInt! + building)
          for _ in 1...10 {
            bsp.blend -= 5
            updateStage()
          }
          for _ in 1...10 {
            bsp.blend += 5
            updateStage()
          }
          bsp.member = member("building_icon_\(building + 1)")
        }
      }
      if todo.getOne(.string("goldaward")) {
        let bsp = sprite(sprites["gold"].asInt!)
        bsp.blend = 100
        updateStage()
      }
      if todo.getOne(.string("newrecord")) {
        let bsp = sprite(sprites["newrecord"].asInt!)
        bsp.blend = 100
        updateStage()
      }
      prop["state"] = .string("showdone")
    case "move2":
      let locEnd = prop["loc"]["end"].asPoint!
      let speedList = prop["speed"]["move2"].asList!
      let spd = [speedList[1].asInt!, speedList[2].asInt!]
      let temp = doMove(toWhere: locEnd, speed: spd)
      if temp != 0 {
        prop["state"] = .string("hide")
        updateLoc(newloc: prop["loc"]["Start"].asPoint!)
        if !prop["callback"].isVoid {
          let cb = prop["callback"].asPropList!
          (cb["object"]).callback(cb["parameter"])
          prop["callback"] = .void
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

  // Original Lingo body: getout
  // ```lingo
  // on getOut me
  //   if not (Prop[#state] = #hide) and not (Prop[#state] = #move2) then
  //     Prop[#state] = #move2
  //   end if
  // end
  // ```
  func getOut() {
    let state = prop["state"].asString!
    if state != "hide" && state != "move2" {
      prop["state"] = .string("move2")
    }
  }

  // Original Lingo body: updatestate
  // ```lingo
  // on updateState me, state, callback
  //   Prop[#callback] = callback
  //   Prop[#state] = state
  // end
  // ```
  func updateState(_ state: String, _ callback: LV = .void) {
    prop["callback"] = callback
    prop["state"] = .string(state)
  }

  // Original Lingo body: updateloc
  // ```lingo
  // on updateLoc me, newloc
  //   sprite(myNum).loc = newloc
  //   repeat with sn = 1 to 3
  //     sprite(myNum + sn).loc = sprite(myNum).loc
  //   end repeat
  //   sprite(myNum + 4).loc = sprite(myNum).loc + point(52, 177) + point(30, -19)
  //   sprite(myNum + 5).loc = sprite(myNum).loc + point(136, 177) + point(29, -14)
  //   sprite(myNum + 6).loc = sprite(myNum).loc + point(217, 177) + point(31, -17)
  //   sprite(myNum + 7).loc = sprite(myNum).loc + point(301, 177) + point(28, -21)
  //   sprite(myNum + 8).loc = sprite(myNum).loc + point(26, 75)
  //   sprite(myNum + 15).loc = sprite(myNum).loc + point(26, 75) + point((keys - 1) * 24, 0)
  //   sprite(myNum + 9).loc = sprite(myNum).loc + point(33, 49)
  //   sprite(myNum + 10).loc = sprite(myNum).loc + point(25, 96)
  //   sprite(myNum + 11).loc = sprite(myNum).loc + point(35, 214)
  //   sprite(myNum + 12).loc = sprite(myNum).loc + point(100, 188)
  //   sprite(myNum + 13).loc = sprite(myNum).loc + point(334, 236)
  //   sprite(myNum + 14).loc = sprite(myNum).loc + point(334, 207)
  // end
  // ```
  func updateLoc(newloc: Point) {
    sprite(myNum).loc = newloc
    for sn in 1...3 {
      sprite(myNum + sn).loc = sprite(myNum).loc
    }
    sprite(myNum + 4).loc = sprite(myNum).loc + Point(x: 52, y: 177) + Point(x: 30, y: -19)
    sprite(myNum + 5).loc = sprite(myNum).loc + Point(x: 136, y: 177) + Point(x: 29, y: -14)
    sprite(myNum + 6).loc = sprite(myNum).loc + Point(x: 217, y: 177) + Point(x: 31, y: -17)
    sprite(myNum + 7).loc = sprite(myNum).loc + Point(x: 301, y: 177) + Point(x: 28, y: -21)
    sprite(myNum + 8).loc = sprite(myNum).loc + Point(x: 26, y: 75)
    sprite(myNum + 15).loc =
      sprite(myNum).loc + Point(x: 26, y: 75) + Point(x: (keys - 1) * 24, y: 0)
    sprite(myNum + 9).loc = sprite(myNum).loc + Point(x: 33, y: 49)
    sprite(myNum + 10).loc = sprite(myNum).loc + Point(x: 25, y: 96)
    sprite(myNum + 11).loc = sprite(myNum).loc + Point(x: 35, y: 214)
    sprite(myNum + 12).loc = sprite(myNum).loc + Point(x: 100, y: 188)
    sprite(myNum + 13).loc = sprite(myNum).loc + Point(x: 334, y: 236)
    sprite(myNum + 14).loc = sprite(myNum).loc + Point(x: 334, y: 207)
  }

  // Original Lingo body: fixlocz
  // ```lingo
  // on fixLocZ me
  //   sprite(myNum).locZ = 1000000000
  //   repeat with sn = 1 to 17
  //     sprite(myNum + sn).locZ = 1000000001 + sn
  //     sprite(myNum + sn).blend = 100
  //     sprite(myNum + sn).visible = 1
  //   end repeat
  // end
  // ```
  func fixLocZ() {
    sprite(myNum).locZ = 1_000_000_000
    for sn in 1...17 {
      sprite(myNum + sn).locZ = 1_000_000_001 + sn
      sprite(myNum + sn).blend = 100
      sprite(myNum + sn).visible = true
    }
  }

  // Original Lingo body: makekey
  // ```lingo
  // on makekey me, keys
  //   member("mem_keys").image = image(400, 20, 8)
  //   img = image(24 * keys, 20, 8)
  //   src = member("key")
  //   repeat with i = 1 to keys
  //     img.copyPixels(src.image, src.rect + rect((i - 1) * 24, 0, (i - 1) * 24, 0), src.rect)
  //     member("mem_keys").image = img
  //     member("mem_keys").regPoint = point(0, 0)
  //   end repeat
  // end
  // ```
  func makekey(keys: Int) {
        // member("mem_keys").image = image(400, 20, 8)
    // Copies key icons side-by-side into mem_keys member
  }
}
