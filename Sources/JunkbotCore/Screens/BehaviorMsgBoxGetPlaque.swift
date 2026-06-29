// Translated from Lingo: behavior_msgBox_GetPlaque (award).ls

class BehaviorMsgBoxGetPlaque {
    var prop: [String: Any] = [:]
    var myNum: Int = 0

    func beginSprite() {
        glob["award_obj"] = self
        prop = [:]
        prop["state"] = "hide"
        prop["loc"] = ["Start": Point(x: 275, y: -190), "show": Point(x: 275, y: 210), "end": Point(x: -325, y: 210)]
        prop["speed"] = ["move1": [0, 40], "move2": [-40, 0]]
        prop["gotgold"] = ""
    }

    func dropBox() {
        let building = (glob["current"] as! [String: Any])["building"] as! Int
        let level = (glob["current"] as! [String: Any])["level"] as! Int
        let moves = (glob["current"] as! [String: Any])["moves"] as! Int
        let gold = (glob["current"] as! [String: Any])["gold"] as! Int
        let goalMoves = ((glob["building"] as! [[String: Any]])[building - 1]["LEVELS"] as! [[String: Any]])[level - 1]["goal"] as! Int
        let gotgold = ((glob["building"] as! [[String: Any]])[building - 1]["LEVELS"] as! [[String: Any]])[level - 1]["gold"] as! Int
        (glob["PLAYER"] as AnyObject).game_manager.TotalKeys()
        let goldNum = (glob["PLAYER"] as AnyObject).game_manager.goldTotal() as! Int
        if (moves <= goalMoves) && (gotgold == 0) {
            var flag = 1
            switch goldNum + 1 {
            case 60:
                glob["plaque"] = "president"
            case 40:
                glob["plaque"] = "year"
            case 30:
                glob["plaque"] = "Month"
            case 20:
                glob["plaque"] = "week"
            case 10:
                glob["plaque"] = "day"
            default:
                flag = 0
            }
            if flag == 1 {
                prop["gotgold"] = glob["plaque"] as! String
                doGoldStuff()
            } else {
                doNextBox()
            }
        } else {
            doNextBox()
        }
    }

    func doGoldStuff() {
        let gotgold = prop["gotgold"] as! String
        if gotgold == "" || gotgold == "welcome" {
            doNextBox()
        } else {
            sprite(myNum + 1).member = member("OfThe" + gotgold)
            setCursor("none")
            sendAllSprites("getOut")
            prop["state"] = "move1"
            fixLocZ()
        }
    }

    func doNextBox() {
        (glob["BIG_MSG_OBJ"] as AnyObject).dropBox()
    }

    func exitFrame() {
        switch prop["state"] as! String {
        case "hide":
            break
        case "move1":
            let locShow = (prop["loc"] as! [String: Any])["show"] as! Point
            let speedMove1 = (prop["speed"] as! [String: Any])["move1"] as! [Int]
            let temp = doMove(toWhere: locShow, speed: speedMove1)
            if temp != 0 {
                prop["state"] = "show"
                SndSFX("goldkey1")
            }
        case "show":
            setCursor("none")
        case "move2":
            let locEnd = (prop["loc"] as! [String: Any])["end"] as! Point
            let speedMove2 = (prop["speed"] as! [String: Any])["move2"] as! [Int]
            let temp = doMove(toWhere: locEnd, speed: speedMove2)
            if temp != 0 {
                prop["state"] = "hide"
                (glob["BIG_MSG_OBJ"] as AnyObject).dropBox()
                updateLoc(newloc: (prop["loc"] as! [String: Any])["Start"] as! Point)
            }
        default:
            break
        }
    }

    @discardableResult
    func doMove(toWhere: Point, speed: [Int]) -> Int {
        switch prop["state"] as! String {
        case "move1":
            if sprite(myNum).locV < toWhere.y {
                let newloc = sprite(myNum).loc + Point(x: speed[0], y: speed[1])
                updateLoc(newloc: newloc)
                return 0
            } else {
                return 1
            }
        case "move2":
            if sprite(myNum).locH > toWhere.x {
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
        prop["state"] = state
    }

    func getOut() {
        let state = prop["state"] as! String
        if state != "hide" && state != "move2" {
            prop["state"] = "move2"
        }
    }

    func reportState() -> String {
        return prop["state"] as! String
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
