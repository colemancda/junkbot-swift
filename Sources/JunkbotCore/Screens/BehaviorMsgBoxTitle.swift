// Translated from Lingo: behavior_msgBox_Title.ls

class BehaviorMsgBoxTitle: LingoObject, @unchecked Sendable {
    var prop: PropList = PropList()
    var myNum: Int = 0

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   myNum = me.spriteNum
    //   glob[#title_obj] = me
    //   Prop = [:]
    //   Prop[#state] = #hide
    //   Prop[#loc] = [#Start: point(100, -190), #show: point(100, 130), #end: point(-300, 130)]
    //   Prop[#speed] = [#move1: [0, 40], #move2: [-40, 0]]
    //   Prop[#sprites] = [#icon: myNum + 1, #num: myNum + 2, #title: myNum + 3]
    // end
    // ```
    func beginSprite() {
        Glob.shared["title_obj"] = .void  // set externally as object reference
        prop = PropList()
        prop["state"] = .string("hide")
        var loc = PropList()
        loc["Start"] = .point(x: 100, y: -190)
        loc["show"] = .point(x: 100, y: 130)
        loc["end"] = .point(x: -300, y: 130)
        prop["loc"] = .propList(loc)
        var speed = PropList()
        speed["move1"] = .list(LingoList([.int(0), .int(40)]))
        speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
        prop["speed"] = .propList(speed)
        var sprites = PropList()
        sprites["icon"] = .int(myNum + 1)
        sprites["num"] = .int(myNum + 2)
        sprites["title"] = .int(myNum + 3)
        prop["sprites"] = .propList(sprites)
    }

    // Original Lingo body: updatedata
    // ```lingo
    // on updateData me, data, callback
    //   sprite(Prop[#sprites][#icon]).member = member("building_icon_" & data[1])
    //   sprite(Prop[#sprites][#num]).member = member("building_title_" & data[1])
    //   member("level_title").text = "LEVEL " & data[2] & ": " & data[3]
    //   Prop[#state] = #move1
    //   me.fixLocZ()
    //   Prop[#callback] = callback
    // end
    // ```
    func updateData(_ data: LingoList, callback: LV = .void) {
        let sprites = prop["sprites"].asPropList!
        let buildingNum = data[1].asInt!
        sprite(sprites["icon"].asInt!).member = member("building_icon_\(buildingNum)")
        sprite(sprites["num"].asInt!).member = member("building_title_\(buildingNum)")
        member("level_title")?.text = "LEVEL \(data[2].asString ?? ""): \(data[3].asString ?? "")"
        prop["state"] = .string("move1")
        fixLocZ()
        prop["callback"] = callback
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
    //         Prop[#time] = the timer
    //         glob[#movenum].updateMovesNum()
    //       end if
    //     #show:
    //       if the timer > (Prop[#time] + 120) then
    //         Prop[#state] = #move2
    //       end if
    //     #move2:
    //       temp = me.doMove(Prop[#loc][#end], Prop[#speed][#move2])
    //       if temp then
    //         Prop[#state] = #done
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
                prop["time"] = .int(currentTicks)
                (Glob.shared["movenum"]).updateMovesNum()
            }
        case "show":
            let t = prop["time"].asInt!
            if currentTicks > (t + 120) {
                prop["state"] = .string("move2")
            }
        case "move2":
            let locEnd = prop["loc"]["end"].asPoint!
            let speedList = prop["speed"]["move2"].asList!
            let spd = [speedList[1].asInt!, speedList[2].asInt!]
            let temp = doMove(toWhere: locEnd, speed: spd)
            if temp != 0 {
                prop["state"] = .string("done")
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

    @discardableResult
    // Original Lingo body: domove
    // ```lingo
    // on doMove me, toWhere, speed
    //   case Prop[#state] of
    //     #move1:
    //       sprite(myNum).locH = Prop[#loc][#show][1]
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
            let locShow = prop["loc"]["show"].asPoint!
            sprite(myNum).loc = Point(x: locShow.x, y: sprite(myNum).loc.y)
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
    //   sprite(Prop[#sprites][1]).loc = sprite(myNum).loc + point(48, 74) + point(30, -20)
    //   sprite(Prop[#sprites][2]).loc = sprite(myNum).loc + point(117, 51)
    //   sprite(Prop[#sprites][3]).loc = sprite(myNum).loc + point(49, 79)
    // end
    // ```
    func updateLoc(newloc: Point) {
        let sprites = prop["sprites"].asPropList!
        sprite(myNum).loc = newloc
        sprite(sprites["icon"].asInt!).loc = sprite(myNum).loc + Point(x: 48, y: 74) + Point(x: 30, y: -20)
        sprite(sprites["num"].asInt!).loc = sprite(myNum).loc + Point(x: 117, y: 51)
        sprite(sprites["title"].asInt!).loc = sprite(myNum).loc + Point(x: 49, y: 79)
    }

    // Original Lingo body: fixlocz
    // ```lingo
    // on fixLocZ me
    //   sprite(myNum).locZ = 1000000000
    //   sprite(Prop[#sprites][1]).locZ = 1000000001
    //   sprite(Prop[#sprites][2]).locZ = 1000000001
    //   sprite(Prop[#sprites][3]).locZ = 1000000001
    // end
    // ```
    func fixLocZ() {
        let sprites = prop["sprites"].asPropList!
        sprite(myNum).locZ = 1000000000
        sprite(sprites["icon"].asInt!).locZ = 1000000001
        sprite(sprites["num"].asInt!).locZ = 1000000001
        sprite(sprites["title"].asInt!).locZ = 1000000001
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
}
