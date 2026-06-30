// Translated from Lingo: behavior_screen_loop.ls

class BehaviorScreenLoop: LingoObject, @unchecked Sendable {
  var selected: Int = 0
  var data: LingoList = LingoList()
  var dataAct: PropList = PropList()

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   glob[#level_scrn_obj] = me
  //   data = glob[#building]
  //   me.setBuilding(glob[#current][#building])
  // end
  // ```
  func beginSprite() {
    Glob.shared["level_scrn_obj"] = .void  // set externally as object reference
    data = Glob.shared["building"].asList!
    let current = Glob.shared["current"].asPropList!
    setBuilding(current["building"].asInt!)
  }

  // Original Lingo body: enterframe
  // ```lingo
  // on enterFrame me
  //   SndMusicEnd()
  // end
  // ```
  func enterFrame() {
    SndMusicEnd()
  }

  // Original Lingo body: totalmoves
  // ```lingo
  // on totalMoves me
  // end
  // ```
  func totalMoves() {
    // no-op
  }

  // Original Lingo body: setbuilding
  // ```lingo
  // on setBuilding me, num
  //   selected = num
  //   dataAct = data[num]
  //   me.checkKeys()
  //   me.updateTabs()
  //   me.updateList()
  // end
  // ```
  func setBuilding(_ num: Int) {
    selected = num
    dataAct = data[num].asPropList!
    checkKeys()
    updateTabs()
    updateList()
  }

  // Original Lingo body: checkkeys
  // ```lingo
  // on checkKeys me
  //   repeat with i = 1 to 4
  //     keys = 0
  //     building = data[i][#LEVELS]
  //     repeat with j = 1 to building.count
  //       if building[j][#moves] > 0 then
  //         keys = keys + 1
  //       end if
  //     end repeat
  //     if (i < 4) and (keys >= glob[#keyrequired]) then
  //       data[i + 1][#state] = #open
  //     end if
  //   end repeat
  // end
  // ```
  func checkKeys() {
    for i in 1...4 {
      var keys = 0
      let building = data[i]["LEVELS"].asList!
      for j in 1...building.count {
        if (building[j]["moves"].asInt ?? 0) > 0 {
          keys += 1
        }
      }
      let keyrequired = Glob.shared["keyrequired"].asInt!
      if (i < 4) && (keys >= keyrequired) {
        data[i + 1]["state"] = .string("open")
      }
    }
  }

  // Original Lingo body: updatetabs
  // ```lingo
  // on updateTabs me
  //   sprite(11).member = member("TAB." & selected)
  //   repeat with sn = 1 to 4
  //     case data[sn][#state] of
  //       #locked:
  //         sprite(11 + sn + 4).member = member("building_icon_" & sn & "_locked")
  //         num = 20
  //       #open:
  //         sprite(11 + sn + 4).member = member("building_icon_" & sn)
  //         if selected = sn then
  //           num = 100
  //         else
  //           num = 50
  //         end if
  //     end case
  //     sprite(11 + sn).blend = num
  //   end repeat
  // end
  // ```
  func updateTabs() {
    sprite(11).member = member("TAB.\(selected)")
    for sn in 1...4 {
      let entry = data[sn].asPropList!
      let state = entry["state"].asString!
      let num: Int
      switch state {
      case "locked":
        sprite(11 + sn + 4).member = member("building_icon_\(sn)_locked")
        num = 20
      case "open":
        sprite(11 + sn + 4).member = member("building_icon_\(sn)")
        num = selected == sn ? 100 : 50
      default:
        num = 0
      }
      sprite(11 + sn).blend = num
    }
  }

  // Original Lingo body: updatelist
  // ```lingo
  // on updateList me
  //   LEVELS = dataAct[#LEVELS]
  //   titleText = EMPTY
  //   movesText = EMPTY
  //   repeat with L = 1 to LEVELS.count
  //     if LEVELS[L][#moves] = 0 then
  //       tempMoves = EMPTY
  //     else
  //       tempMoves = LEVELS[L][#moves]
  //     end if
  //     movesText = movesText & tempMoves & RETURN
  //     titleText = titleText & LEVELS[L][#title] & RETURN
  //     if LEVELS[L][#moves] > 0 then
  //       sprite(39 + L).member = member("checkbox_on")
  //       sprite(39 + L).blend = 100
  //       if LEVELS[L][#goal] >= LEVELS[L][#moves] then
  //         sprite(54 + L).blend = 100
  //       else
  //         sprite(54 + L).blend = 0
  //       end if
  //       next repeat
  //     end if
  //     sprite(39 + L).member = member("checkbox_off")
  //     sprite(39 + L).blend = 100
  //     sprite(54 + L).blend = 0
  //   end repeat
  //   member("level.name").text = titleText
  //   member("level.name").FixedLinespace = 21
  //   member("level.moves").text = movesText
  //   member("level.moves").alignment = #right
  //   member("level.moves").FixedLinespace = 21
  // end
  // ```
  func updateList() {
    let levels = dataAct["LEVELS"].asList!
    var titleText = ""
    var movesText = ""
    for l in 1...levels.count {
      let levelEntry = levels[l].asPropList!
      let movesVal = levelEntry["moves"].asInt ?? 0
      let tempMoves = movesVal == 0 ? "" : String(movesVal)
      movesText += tempMoves + "\n"
      titleText += (levelEntry["title"].asString ?? "") + "\n"
      if movesVal > 0 {
        sprite(39 + l).member = member("checkbox_on")
        sprite(39 + l).blend = 100
        if (levelEntry["goal"].asInt ?? 0) >= movesVal {
          sprite(54 + l).blend = 100
        } else {
          sprite(54 + l).blend = 0
        }
        continue
      }
      sprite(39 + l).member = member("checkbox_off")
      sprite(39 + l).blend = 100
      sprite(54 + l).blend = 0
    }
    member("level.name")?.text = titleText
    member("level.moves")?.text = movesText
  }

  // Original Lingo body: rotab
  // ```lingo
  // on roTab me, snum, bnum
  //   if data[snum - 23][#state] = #open then
  //     return 0
  //   end if
  //   sprite(snum - 4).blend = bnum
  //   return 1
  // end
  // ```
  func roTab(_ snum: Int, _ bnum: Int) -> Int {
    if data[snum - 24]["state"].asString == "open" {
      return 0
    }
    sprite(snum - 4).blend = bnum
    return 1
  }

  // Original Lingo body: tabclicked
  // ```lingo
  // on tabClicked me, snum
  //   clicked = snum - 23
  //   if data[clicked][#state] = #locked then
  //     SndSFX("spring_1")
  //     exit
  //   end if
  //   if clicked = selected then
  //     exit
  //   end if
  //   SndSFX("h_powerup3")
  //   glob.current.building = clicked
  //   me.setBuilding(clicked)
  // end
  // ```
  func tabClicked(_ snum: Int) {
    let clicked = snum - 23
    if data[clicked]["state"].asString == "locked" {
      SndSFX("spring_1")
      return
    }
    if clicked == selected {
      return
    }
    SndSFX("h_powerup3")
    let current = Glob.shared["current"].asPropList!
    current["building"] = .int(clicked)
    setBuilding(clicked)
  }

  // Original Lingo body: exitframe
  // ```lingo
  // on exitFrame me
  //   go(the frame)
  // end
  // ```
  func exitFrame() {
    go(theFrame)
  }
}
