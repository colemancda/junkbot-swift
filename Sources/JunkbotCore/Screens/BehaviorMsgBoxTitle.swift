// Translated from Lingo: behavior_msgBox_Title.ls

class BehaviorMsgBoxTitle {
    var prop: PropList = PropList()
    var myNum: Int = 0

    func beginSprite() {
        Glob.shared["title_obj"] = .void  // set externally as object reference
        prop = PropList()
        prop["state"] = .string("hide")
        let loc = PropList()
        loc["Start"] = .point(x: 100, y: -190)
        loc["show"] = .point(x: 100, y: 130)
        loc["end"] = .point(x: -300, y: 130)
        prop["loc"] = .propList(loc)
        let speed = PropList()
        speed["move1"] = .list(LingoList([.int(0), .int(40)]))
        speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
        prop["speed"] = .propList(speed)
        let sprites = PropList()
        sprites["icon"] = .int(myNum + 1)
        sprites["num"] = .int(myNum + 2)
        sprites["title"] = .int(myNum + 3)
        prop["sprites"] = .propList(sprites)
    }

    func updateData(_ data: LingoList, callback: LV = .void) {
        let sprites = prop["sprites"].asPropList!
        let buildingNum = data[1].asInt!
        sprite(sprites["icon"].asInt!).member = member("building_icon_\(buildingNum)")
        sprite(sprites["num"].asInt!).member = member("building_title_\(buildingNum)")
        member("level_title").text = "LEVEL \(data[2].asString ?? ""): \(data[3].asString ?? "")"
        prop["state"] = .string("move1")
        fixLocZ()
        prop["callback"] = callback
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

    func getOut() {
        let state = prop["state"].asString!
        if state != "hide" && state != "move2" {
            prop["state"] = .string("move2")
        }
    }

    @discardableResult
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

    func updateLoc(newloc: Point) {
        let sprites = prop["sprites"].asPropList!
        sprite(myNum).loc = newloc
        sprite(sprites["icon"].asInt!).loc = sprite(myNum).loc + Point(x: 48, y: 74) + Point(x: 30, y: -20)
        sprite(sprites["num"].asInt!).loc = sprite(myNum).loc + Point(x: 117, y: 51)
        sprite(sprites["title"].asInt!).loc = sprite(myNum).loc + Point(x: 49, y: 79)
    }

    func fixLocZ() {
        let sprites = prop["sprites"].asPropList!
        sprite(myNum).locZ = 1000000000
        sprite(sprites["icon"].asInt!).locZ = 1000000001
        sprite(sprites["num"].asInt!).locZ = 1000000001
        sprite(sprites["title"].asInt!).locZ = 1000000001
    }

    func mouseUp() {
        prop["state"] = .string("move2")
    }
}
