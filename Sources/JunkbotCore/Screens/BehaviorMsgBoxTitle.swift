// Translated from Lingo: behavior_msgBox_Title.ls

class BehaviorMsgBoxTitle {
    var prop: [String: Any] = [:]
    var myNum: Int = 0

    func beginSprite() {
        glob["title_obj"] = self
        prop = [:]
        prop["state"] = "hide"
        prop["loc"] = ["Start": Point(x: 100, y: -190), "show": Point(x: 100, y: 130), "end": Point(x: -300, y: 130)]
        prop["speed"] = ["move1": [0, 40], "move2": [-40, 0]]
        prop["sprites"] = ["icon": myNum + 1, "num": myNum + 2, "title": myNum + 3]
    }

    func updateData(_ data: [Any], callback: Any?) {
        let sprites = prop["sprites"] as! [String: Int]
        let buildingNum = data[0] as! Int
        sprite(sprites["icon"]!).member = member("building_icon_\(buildingNum)")
        sprite(sprites["num"]!).member = member("building_title_\(buildingNum)")
        member("level_title").text = "LEVEL \(data[1]): \(data[2])"
        prop["state"] = "move1"
        fixLocZ()
        prop["callback"] = callback
    }

    func updateState(_ state: String) {
        prop["state"] = state
    }

    func reportState() -> String {
        return prop["state"] as! String
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
                prop["time"] = Int(Date().timeIntervalSince1970 * 60)
                (glob["movenum"] as AnyObject).updateMovesNum()
            }
        case "show":
            let t = prop["time"] as! Int
            if Int(Date().timeIntervalSince1970 * 60) > (t + 120) {
                prop["state"] = "move2"
            }
        case "move2":
            let locEnd = (prop["loc"] as! [String: Any])["end"] as! Point
            let speedMove2 = (prop["speed"] as! [String: Any])["move2"] as! [Int]
            let temp = doMove(toWhere: locEnd, speed: speedMove2)
            if temp != 0 {
                prop["state"] = "done"
                updateLoc(newloc: (prop["loc"] as! [String: Any])["Start"] as! Point)
                if prop["callback"] != nil {
                    let cb = prop["callback"] as! [String: Any]
                    (cb["object"] as AnyObject).callback(cb["parameter"])
                    prop["callback"] = nil
                }
            }
        default:
            break
        }
    }

    func getOut() {
        let state = prop["state"] as! String
        if state != "hide" && state != "move2" {
            prop["state"] = "move2"
        }
    }

    @discardableResult
    func doMove(toWhere: Point, speed: [Int]) -> Int {
        switch prop["state"] as! String {
        case "move1":
            let locShow = (prop["loc"] as! [String: Any])["show"] as! Point
            sprite(myNum).locH = locShow.x
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

    func updateLoc(newloc: Point) {
        let sprites = prop["sprites"] as! [String: Int]
        sprite(myNum).loc = newloc
        sprite(sprites["icon"]!).loc = sprite(myNum).loc + Point(x: 48, y: 74) + Point(x: 30, y: -20)
        sprite(sprites["num"]!).loc = sprite(myNum).loc + Point(x: 117, y: 51)
        sprite(sprites["title"]!).loc = sprite(myNum).loc + Point(x: 49, y: 79)
    }

    func fixLocZ() {
        let sprites = prop["sprites"] as! [String: Int]
        sprite(myNum).locZ = 1000000000
        sprite(sprites["icon"]!).locZ = 1000000001
        sprite(sprites["num"]!).locZ = 1000000001
        sprite(sprites["title"]!).locZ = 1000000001
    }

    func mouseUp() {
        prop["state"] = "move2"
    }
}
