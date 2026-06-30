// Translated from Lingo: behavior_msgBox_GetPlaque (award).ls

class BehaviorMsgBoxGetPlaque: LingoObject, @unchecked Sendable {
    var prop: PropList = PropList()
    var myNum: Int = 0

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   myNum = me.spriteNum
    //   glob[#award_obj] = me
    //   Prop = [:]
    //   Prop[#state] = #hide
    //   Prop[#loc] = [#Start: point(275, -190), #show: point(275, 210), #end: point(-325, 210)]
    //   Prop[#speed] = [#move1: [0, 40], #move2: [-40, 0]]
    //   Prop[#gotgold] = EMPTY
    // end
    // ```
    func beginSprite() {
        Glob.shared["award_obj"] = .void  // set externally as object reference
        prop = PropList()
        prop["state"] = .string("hide")
        var loc = PropList()
        loc["Start"] = .point(x: 275, y: -190)
        loc["show"] = .point(x: 275, y: 210)
        loc["end"] = .point(x: -325, y: 210)
        prop["loc"] = .propList(loc)
        var speed = PropList()
        speed["move1"] = .list(LingoList([.int(0), .int(40)]))
        speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
        prop["speed"] = .propList(speed)
        prop["gotgold"] = .string("")
    }

    // Original Lingo body: dropbox
    // ```lingo
    // on dropBox me
    //   building = glob[#current][#building]
    //   level = glob[#current][#level]
    //   moves = glob[#current][#moves]
    //   gold = glob[#current][#gold]
    //   goalMoves = glob[#building][building][#LEVELS][level][#goal]
    //   gotgold = glob[#building][building][#LEVELS][level][#gold]
    //   data = glob[#building][building][#LEVELS][level][#moves]
    //   glob.PLAYER[#game_manager].TotalKeys()
    //   goldNum = glob.PLAYER[#game_manager].goldTotal()
    //   if (moves <= goalMoves) and (gotgold = 0) then
    //     flag = 1
    //     case goldNum + 1 of
    //       60:
    //         glob[#plaque] = "president"
    //       40:
    //         glob[#plaque] = "year"
    //       30:
    //         glob[#plaque] = "Month"
    //       20:
    //         glob[#plaque] = "week"
    //       10:
    //         glob[#plaque] = "day"
    //       otherwise:
    //         flag = 0
    //     end case
    //     if flag = 1 then
    //       Prop[#gotgold] = glob[#plaque]
    //       me.doGoldStuff()
    //     else
    //       me.doNextBox()
    //     end if
    //   else
    //     me.doNextBox()
    //   end if
    // end
    // ```
    func dropBox() {
        let current = Glob.shared["current"].asPropList!
        let building = current["building"].asInt!
        let level = current["level"].asInt!
        let moves = current["moves"].asInt!
        let buildingList = Glob.shared["building"].asList!
        let buildingEntry = buildingList[building].asPropList!
        let levels = buildingEntry["LEVELS"].asList!
        let levelEntry = levels[level].asPropList!
        let goalMoves = levelEntry["goal"].asInt!
        let gotgold = levelEntry["gold"].asInt!
        (Glob.shared["PLAYER"]).game_manager.TotalKeys()
        let goldNum: Int = (Glob.shared["PLAYER"]).game_manager.goldTotal().asInt ?? 0
        if (moves <= goalMoves) && (gotgold == 0) {
            var flag = 1
            switch goldNum + 1 {
            case 60:
                Glob.shared["plaque"] = .string("president")
            case 40:
                Glob.shared["plaque"] = .string("year")
            case 30:
                Glob.shared["plaque"] = .string("Month")
            case 20:
                Glob.shared["plaque"] = .string("week")
            case 10:
                Glob.shared["plaque"] = .string("day")
            default:
                flag = 0
            }
            if flag == 1 {
                prop["gotgold"] = Glob.shared["plaque"]
                doGoldStuff()
            } else {
                doNextBox()
            }
        } else {
            doNextBox()
        }
    }

    // Original Lingo body: dogoldstuff
    // ```lingo
    // on doGoldStuff me
    //   if (Prop[#gotgold] = EMPTY) or (Prop[#gotgold] = "welcome") then
    //     me.doNextBox()
    //   else
    //     sprite(myNum + 1).member = member("OfThe" & Prop[#gotgold])
    //     setCursor(#none)
    //     sendAllSprites(#getOut)
    //     Prop[#state] = #move1
    //     me.fixLocZ()
    //   end if
    // end
    // ```
    func doGoldStuff() {
        let gotgold = prop["gotgold"].asString ?? ""
        if gotgold == "" || gotgold == "welcome" {
            doNextBox()
        } else {
            sprite(myNum + 1).member = member("OfThe" + gotgold)
            setCursor("none")
            sendAllSprites("getOut")
            prop["state"] = .string("move1")
            fixLocZ()
        }
    }

    // Original Lingo body: donextbox
    // ```lingo
    // on doNextBox me
    //   glob[#BIG_MSG_OBJ].dropBox()
    // end
    // ```
    func doNextBox() {
        (Glob.shared["BIG_MSG_OBJ"]).dropBox()
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
    //         SndSFX("goldkey1")
    //       end if
    //     #show:
    //       setCursor(#none)
    //     #move2:
    //       temp = me.doMove(Prop[#loc][#end], Prop[#speed][#move2])
    //       if temp then
    //         Prop[#state] = #hide
    //         glob[#BIG_MSG_OBJ].dropBox()
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
            if temp != 0 {
                prop["state"] = .string("show")
                SndSFX("goldkey1")
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
                (Glob.shared["BIG_MSG_OBJ"]).dropBox()
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

    // Original Lingo body: updatestate
    // ```lingo
    // on updateState me, state
    //   Prop[#state] = state
    // end
    // ```
    func updateState(_ state: String) {
        prop["state"] = .string(state)
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
    //   sprite(myNum + 1).loc = sprite(myNum).loc + point(0, 94)
    //   sprite(myNum + 2).loc = sprite(myNum).loc + point(0, 137)
    // end
    // ```
    func updateLoc(newloc: Point) {
        sprite(myNum).loc = newloc
        sprite(myNum + 1).loc = sprite(myNum).loc + Point(x: 0, y: 94)
        sprite(myNum + 2).loc = sprite(myNum).loc + Point(x: 0, y: 137)
    }

    // Original Lingo body: fixlocz
    // ```lingo
    // on fixLocZ me
    //   sprite(myNum).locZ = 1000000000
    //   sprite(myNum + 1).locZ = 1000000001
    //   sprite(myNum + 2).locZ = 1000000001
    // end
    // ```
    func fixLocZ() {
        sprite(myNum).locZ = 1000000000
        sprite(myNum + 1).locZ = 1000000001
        sprite(myNum + 2).locZ = 1000000001
    }
}
