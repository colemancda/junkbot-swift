// Translated from Lingo: behavior_msgBox_HINT.ls

class BehaviorMsgBoxHint {
    var prop: [String: Any] = [:]
    var myNum: Int = 0

    func beginSprite() {
        glob["hint_obj"] = self
        prop = [:]
        prop["state"] = "hide"
        prop["loc"] = ["Start": Point(x: 275, y: -125), "show": Point(x: 275, y: 215), "end": Point(x: -195, y: 215)]
        prop["speed"] = ["move1": [0, 40], "move2": [-40, 0]]
    }

    func dropBox() {
        let building = (glob["current"] as! [String: Any])["building"] as! Int
        let level = (glob["current"] as! [String: Any])["level"] as! Int
        let hint = (glob["building"] as AnyObject).building(building).LEVELS(level).info.hint as! String
        member("hint_text").text = "level \(level) hint:\n\(hint)"
        prop["state"] = "move1"
        prop["gameState"] = (glob["PLAYER"] as AnyObject).play_manager.activeState
        (glob["PLAYER"] as AnyObject).play_manager.activeState = "pause"
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
            }
        case "show":
            setCursor("none")
        case "move2":
            let locEnd = (prop["loc"] as! [String: Any])["end"] as! Point
            let speedMove2 = (prop["speed"] as! [String: Any])["move2"] as! [Int]
            let temp = doMove(toWhere: locEnd, speed: speedMove2)
            if temp != 0 {
                prop["state"] = "done"
                updateLoc(newloc: (prop["loc"] as! [String: Any])["Start"] as! Point)
                if (prop["gameState"] as? String) == "pause" {
                    gbutton("main_play")
                } else {
                    (glob["PLAYER"] as AnyObject).play_manager.activeState = "Run"
                }
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

    func updateLoc(newloc: Point) {
        sprite(myNum).loc = newloc
        sprite(myNum + 1).loc = sprite(myNum).loc + Point(x: 0, y: 53)
        sprite(myNum + 2).loc = sprite(myNum).loc + Point(x: -139, y: -83)
    }

    func fixLocZ() {
        // no-op
    }

    func mouseUp() {
        prop["state"] = "move2"
    }

    func getOut() {
        if (prop["state"] as! String) == "show" {
            prop["state"] = "move2"
        }
    }
}
