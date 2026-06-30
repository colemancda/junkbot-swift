// Translated from Lingo: behavior_msgBox_HINT.ls

class BehaviorMsgBoxHint {
    var prop: PropList = PropList()
    var myNum: Int = 0

    func beginSprite() {
        Glob.shared["hint_obj"] = .void  // set externally as object reference
        prop = PropList()
        prop["state"] = .string("hide")
        let loc = PropList()
        loc["Start"] = .point(x: 275, y: -125)
        loc["show"] = .point(x: 275, y: 215)
        loc["end"] = .point(x: -195, y: 215)
        prop["loc"] = .propList(loc)
        let speed = PropList()
        speed["move1"] = .list(LingoList([.int(0), .int(40)]))
        speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
        prop["speed"] = .propList(speed)
    }

    func dropBox() {
        let current = Glob.shared["current"].asPropList!
        let building = current["building"].asInt!
        let level = current["level"].asInt!
        let hint: String = (Glob.shared["building"]).building(.int(building)).LEVELS(.int(level)).info.hint.asString ?? ""
        member("hint_text").text = "level \(level) hint:\n\(hint)"
        prop["state"] = .string("move1")
        prop["gameState"] = (Glob.shared["PLAYER"]).play_manager.activeState
        (Glob.shared["PLAYER"]).play_manager.activeState = "pause"
    }

    func updateState(_ state: String) {
        prop["state"] = .string(state)
    }

    func reportState() -> String {
        return prop["state"].asString!
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
            if temp != 0 {
                prop["state"] = .string("show")
            }
        case "show":
            setCursor("none")
        case "move2":
            let locEnd = prop["loc"]["end"].asPoint!
            let speedList = prop["speed"]["move2"].asList!
            let spd = [speedList[1].asInt!, speedList[2].asInt!]
            let temp = doMove(toWhere: locEnd, speed: spd)
            if temp != 0 {
                prop["state"] = .string("done")
                updateLoc(newloc: prop["loc"]["Start"].asPoint!)
                if prop["gameState"].asString == "pause" {
                    gbutton("main_play")
                } else {
                    (Glob.shared["PLAYER"]).play_manager.activeState = "Run"
                }
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

    func updateLoc(newloc: Point) {
        sprite(myNum).loc = newloc
        sprite(myNum + 1).loc = sprite(myNum).loc + Point(x: 0, y: 53)
        sprite(myNum + 2).loc = sprite(myNum).loc + Point(x: -139, y: -83)
    }

    func fixLocZ() {
        // no-op
    }

    func mouseUp() {
        prop["state"] = .string("move2")
    }

    func getOut() {
        if prop["state"].asString == "show" {
            prop["state"] = .string("move2")
        }
    }
}
