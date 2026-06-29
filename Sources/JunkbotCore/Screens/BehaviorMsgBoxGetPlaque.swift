// Translated from Lingo: behavior_msgBox_GetPlaque (award).ls

class BehaviorMsgBoxGetPlaque {
    var prop: PropList = PropList()
    var myNum: Int = 0

    func beginSprite() {
        Glob.shared["award_obj"] = .void  // set externally as object reference
        prop = PropList()
        prop["state"] = .string("hide")
        let loc = PropList()
        loc["Start"] = .point(x: 275, y: -190)
        loc["show"] = .point(x: 275, y: 210)
        loc["end"] = .point(x: -325, y: 210)
        prop["loc"] = .propList(loc)
        let speed = PropList()
        speed["move1"] = .list(LingoList([.int(0), .int(40)]))
        speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
        prop["speed"] = .propList(speed)
        prop["gotgold"] = .string("")
    }

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
        (Glob.shared["PLAYER"] as AnyObject).game_manager.TotalKeys()
        let goldNum: Int = (Glob.shared["PLAYER"] as AnyObject).game_manager.goldTotal()
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

    func doNextBox() {
        (Glob.shared["BIG_MSG_OBJ"] as AnyObject).dropBox()
    }

    func exitFrame() {
        switch prop["state"].asString! {
        case "hide":
            break
        case "move1":
            let locShow = prop["loc"].asPropList!["show"].asPoint!
            let speedList = prop["speed"].asPropList!["move1"].asList!
            let spd = [speedList[1].asInt!, speedList[2].asInt!]
            let temp = doMove(toWhere: locShow, speed: spd)
            if temp != 0 {
                prop["state"] = .string("show")
                SndSFX("goldkey1")
            }
        case "show":
            setCursor("none")
        case "move2":
            let locEnd = prop["loc"].asPropList!["end"].asPoint!
            let speedList = prop["speed"].asPropList!["move2"].asList!
            let spd = [speedList[1].asInt!, speedList[2].asInt!]
            let temp = doMove(toWhere: locEnd, speed: spd)
            if temp != 0 {
                prop["state"] = .string("hide")
                (Glob.shared["BIG_MSG_OBJ"] as AnyObject).dropBox()
                updateLoc(newloc: prop["loc"].asPropList!["Start"].asPoint!)
            }
        default:
            break
        }
    }

    @discardableResult
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

    func updateState(_ state: String) {
        prop["state"] = .string(state)
    }

    func getOut() {
        let state = prop["state"].asString!
        if state != "hide" && state != "move2" {
            prop["state"] = .string("move2")
        }
    }

    func reportState() -> String {
        return prop["state"].asString!
    }

    func updateLoc(newloc: Point) {
        sprite(myNum).loc = newloc
        sprite(myNum + 1).loc = sprite(myNum).loc + Point(x: 0, y: 94)
        sprite(myNum + 2).loc = sprite(myNum).loc + Point(x: 0, y: 137)
    }

    func fixLocZ() {
        sprite(myNum).locZ = 1000000000
        sprite(myNum + 1).locZ = 1000000001
        sprite(myNum + 2).locZ = 1000000001
    }
}
