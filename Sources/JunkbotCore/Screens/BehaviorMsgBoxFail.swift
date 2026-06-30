// Translated from Lingo: behavior_msgBox_Fail.ls

class BehaviorMsgBoxFail: LingoObject, @unchecked Sendable {
  var prop: PropList = PropList()
  var myNum: Int = 0

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   myNum = me.spriteNum
  //   glob[#fail_msg_obj] = me
  //   Prop = [:]
  //   Prop[#state] = #hide
  //   Prop[#loc] = [#Start: point(100, -190), #show: point(100, 130), #end: point(-300, 130)]
  //   Prop[#speed] = [#move1: [0, 40], #move2: [-40, 0]]
  //   Prop[#sprites] = [#ouch: myNum + 1, #but1: myNum + 2, #but2: myNum + 3, #but3: myNum + 4, #msg: myNum + 5]
  // end
  // ```
  func beginSprite() {
    myNum = spriteNum
    Glob.shared["fail_msg_obj"] = .void  // set externally as object reference
    prop = PropList()
    prop["state"] = .string("hide")
    var loc = PropList()
    loc["Start"] = .point(x: 100, y: -190)
    loc["show"] = .point(x: 100, y: 130)
    loc["end"] = .point(x: -300, y: 130)
    prop["loc"] = .propList(loc)
    var speed = PropList()
    let move1 = LingoList([.int(0), .int(40)])
    let move2 = LingoList([.int(-40), .int(0)])
    speed["move1"] = .list(move1)
    speed["move2"] = .list(move2)
    prop["speed"] = .propList(speed)
    var sprites = PropList()
    sprites["ouch"] = .int(myNum + 1)
    sprites["but1"] = .int(myNum + 2)
    sprites["but2"] = .int(myNum + 3)
    sprites["but3"] = .int(myNum + 4)
    sprites["msg"] = .int(myNum + 5)
    prop["sprites"] = .propList(sprites)
  }

  // Original Lingo body: updatedata
  // ```lingo
  // on updateData me
  //   msg = ["I hate Mondays.", "I knew that was going to happen.", "Why me?", "There's got to be a better way."]
  //   member("fail_msg").text = msg[random(msg.count)]
  //   setCursor(#none)
  //   sendAllSprites(#getOut)
  //   Prop[#state] = #move1
  //   me.fixLocZ()
  // end
  // ```
  func updateData() {
    let msgs = [
      "I hate Mondays.", "I knew that was going to happen.", "Why me?",
      "There's got to be a better way.",
    ]
    member("fail_msg")?.text = msgs[lingoRandom(msgs.count) - 1]
    setCursor("none")
    sendAllSprites("getOut")
    prop["state"] = .string("move1")
    fixLocZ()
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
  //         if random(2) = 1 then
  //           SndSFX("voice_ouch")
  //         else
  //           SndSFX("voice_uhoh")
  //         end if
  //       end if
  //     #show:
  //       setCursor(#none)
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
        if lingoRandom(2) == 1 {
          SndSFX("voice_ouch")
        } else {
          SndSFX("voice_uhoh")
        }
      }
    case "show":
      setCursor("none")
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
  //   repeat with sn = 1 to 4
  //     sprite(Prop[#sprites][sn]).loc = sprite(myNum).loc
  //   end repeat
  //   sprite(Prop[#sprites][5]).loc = sprite(myNum).loc + point(77, 50)
  // end
  // ```
  func updateLoc(newloc: Point) {
    sprite(myNum).loc = newloc
    let sprites = prop["sprites"].asPropList!
    let keys = ["ouch", "but1", "but2", "but3"]
    for key in keys {
      sprite(sprites[key].asInt!).loc = sprite(myNum).loc
    }
    sprite(sprites["msg"].asInt!).loc = sprite(myNum).loc + Point(x: 77, y: 50)
  }

  // Original Lingo body: fixlocz
  // ```lingo
  // on fixLocZ me
  //   sprite(myNum).locZ = 1000000000
  //   repeat with sn in Prop[#sprites]
  //     sprite(sn).locZ = 1000000001
  //   end repeat
  // end
  // ```
  func fixLocZ() {
    sprite(myNum).locZ = 1_000_000_000
    let sprites = prop["sprites"].asPropList!
    for pair in sprites.props {
      sprite(pair.value.asInt!).locZ = 1_000_000_001
    }
  }

  var spriteNum: Int { return myNum }
}
