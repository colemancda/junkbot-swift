// Translated from Lingo: behavior_msgBox_IntoHallOfFame.ls

class BehaviorMsgBoxIntoHallOfFame {
    var myNum: Int = 0
    var prop: [String: Any] = [:]
    var waiting: Int = 0

    func beginSprite() {
        glob["master_obj"] = self
        prop = [:]
        prop["state"] = "hide"
        prop["loc"] = ["Start": Point(x: 275, y: -220), "show": Point(x: 265, y: 210), "end": Point(x: -455, y: 210)]
        prop["speed"] = ["move1": [0, 40], "move2": [-40, 0]]
        (glob["PLAYER"] as AnyObject).game_manager.TotalKeys()
    }

    func dropBox() {
        let building = (glob["current"] as! [String: Any])["building"] as! Int
        let level = (glob["current"] as! [String: Any])["level"] as! Int
        let data = ((glob["building"] as! [[String: Any]])[building - 1]["LEVELS"] as! [[String: Any]])[level - 1]
        (glob["PLAYER"] as AnyObject).game_manager.TotalKeys()
        let rankdata = glob["rankdata"] as! [String: Any]
        let rankKeys = rankdata["keys"] as! Int
        let hof = glob["hof"] as! Int
        if (rankKeys + 1) < hof {
            (glob["award_obj"] as AnyObject).dropBox()
        } else {
            if (rankdata["AlreadySawHOF"] as? String) == "YES" {
                (glob["award_obj"] as AnyObject).dropBox()
            } else {
                if (data["moves"] as! Int) > 0 {
                    (glob["award_obj"] as AnyObject).dropBox()
                } else {
                    if !((rankdata["AlreadySawHOF"] as? String) == "YES") {
                        var rankdataMut = glob["rankdata"] as! [String: Any]
                        rankdataMut["AlreadySawHOF"] = "YES"
                        glob["rankdata"] = rankdataMut
                        prop["state"] = "move1"
                        setCursor("none")
                        updateScreen()
                        fixLocZ()
                    }
                }
            }
        }
    }

    func updateScreen() {
        let rankdata = glob["rankdata"] as! [String: Any]
        member("total.moves").text = String(rankdata["moves"] as! Int)
        if (rankdata["serverState"] as? String) == "READY" {
            let barwidth = 125
            let rank = rankdata["rank"] as! Int
            let total = rankdata["players"] as! Int
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
        let masterObj = glob["master_obj"] as! BehaviorMsgBoxIntoHallOfFame
        switch masterObj.prop["state"] as! String {
        case "hide":
            break
        case "move1":
            let locShow = (prop["loc"] as! [String: Any])["show"] as! Point
            let speedMove1 = (prop["speed"] as! [String: Any])["move1"] as! [Int]
            let temp = doMove(toWhere: locShow, speed: speedMove1)
            if temp == 1 {
                masterObj.prop["state"] = "show"
                waiting = Int(Date().timeIntervalSince1970 * 60)
            }
        case "show":
            setCursor("none")
            updateScreen()
            if Int(Date().timeIntervalSince1970 * 60) > (waiting + 300) {
                sprite(myNum + 3).loc = Point(x: 1000, y: 1000)
            }
        case "move2":
            let locEnd = (prop["loc"] as! [String: Any])["end"] as! Point
            let speedMove2 = (prop["speed"] as! [String: Any])["move2"] as! [Int]
            let temp = doMove(toWhere: locEnd, speed: speedMove2)
            if temp != 0 {
                masterObj.prop["state"] = "done"
                updateLoc(newloc: (prop["loc"] as! [String: Any])["Start"] as! Point)
            }
        default:
            break
        }
    }

    @discardableResult
    func doMove(toWhere: Point, speed: [Int]) -> Int {
        let masterObj = glob["master_obj"] as! BehaviorMsgBoxIntoHallOfFame
        switch masterObj.prop["state"] as! String {
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

    func getOut() {
        if (prop["state"] as! String) == "show" {
            prop["state"] = "move2"
        }
    }

    func reportState() -> String {
        return prop["state"] as! String
    }

    func updateLoc(newloc: Point) {
        sprite(myNum).loc = newloc
        sprite(myNum + 1).loc = sprite(myNum).loc + Point(x: -189, y: 125)
        sprite(myNum + 2).loc = sprite(myNum).loc + Point(x: 146, y: 150)
        let masterObj = glob["master_obj"] as! BehaviorMsgBoxIntoHallOfFame
        if !((masterObj.prop["state"] as! String) == "move2") {
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
