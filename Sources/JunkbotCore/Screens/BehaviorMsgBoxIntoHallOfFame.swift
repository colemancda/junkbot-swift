// Translated from Lingo: behavior_msgBox_IntoHallOfFame.ls

class BehaviorMsgBoxIntoHallOfFame {
    var myNum: Int = 0
    var prop: PropList = PropList()
    var waiting: Int = 0

    func beginSprite() {
        Glob.shared["master_obj"] = .void  // set externally as object reference
        prop = PropList()
        prop["state"] = .string("hide")
        let loc = PropList()
        loc["Start"] = .point(x: 275, y: -220)
        loc["show"] = .point(x: 265, y: 210)
        loc["end"] = .point(x: -455, y: 210)
        prop["loc"] = .propList(loc)
        let speed = PropList()
        speed["move1"] = .list(LingoList([.int(0), .int(40)]))
        speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
        prop["speed"] = .propList(speed)
        (Glob.shared["PLAYER"]).game_manager.TotalKeys()
    }

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

    func updateScreen() {
        let rankdata = Glob.shared["rankdata"].asPropList!
        member("total.moves").text = String(rankdata["moves"].asInt!)
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
            member("rank_box1").text = String(rank)
            member("rank_box2").text = "out of \(total)"
        } else {
            member("rank_box1").text = "processing"
            member("rank_box2").text = ""
        }
    }

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

    func getOut() {
        if prop["state"].asString == "show" {
            prop["state"] = .string("move2")
        }
    }

    func reportState() -> String {
        return prop["state"].asString!
    }

    func updateLoc(newloc: Point) {
        sprite(myNum).loc = newloc
        sprite(myNum + 1).loc = sprite(myNum).loc + Point(x: -189, y: 125)
        sprite(myNum + 2).loc = sprite(myNum).loc + Point(x: 146, y: 150)
        if !(prop["state"].asString == "move2") {
            sprite(myNum + 3).loc = sprite(myNum).loc + Point(x: 0, y: -1)
        }
    }

    func fixLocZ() {
        sprite(myNum).locZ = 1000000000
        sprite(myNum + 1).locZ = 1000000001
        sprite(myNum + 2).locZ = 1000000001
        sprite(myNum + 3).locZ = 1000000002
    }
}
