// Translated from Lingo: behavior_msgBox_Fail.ls

class BehaviorMsgBoxFail {
    var prop: PropList = PropList()
    var myNum: Int = 0

    func beginSprite() {
        myNum = spriteNum
        Glob.shared["fail_msg_obj"] = .void  // set externally as object reference
        prop = PropList()
        prop["state"] = .string("hide")
        let loc = PropList()
        loc["Start"] = .point(x: 100, y: -190)
        loc["show"] = .point(x: 100, y: 130)
        loc["end"] = .point(x: -300, y: 130)
        prop["loc"] = .propList(loc)
        let speed = PropList()
        let move1 = LingoList([.int(0), .int(40)])
        let move2 = LingoList([.int(-40), .int(0)])
        speed["move1"] = .list(move1)
        speed["move2"] = .list(move2)
        prop["speed"] = .propList(speed)
        let sprites = PropList()
        sprites["ouch"] = .int(myNum + 1)
        sprites["but1"] = .int(myNum + 2)
        sprites["but2"] = .int(myNum + 3)
        sprites["but3"] = .int(myNum + 4)
        sprites["msg"] = .int(myNum + 5)
        prop["sprites"] = .propList(sprites)
    }

    func updateData() {
        let msgs = ["I hate Mondays.", "I knew that was going to happen.", "Why me?", "There's got to be a better way."]
        member("fail_msg").text = msgs[lingoRandom(msgs.count) - 1]
        setCursor("none")
        sendAllSprites("getOut")
        prop["state"] = .string("move1")
        fixLocZ()
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
                if lingoRandom(2) == 1 {
                    SndSFX("voice_ouch")
                } else {
                    SndSFX("voice_uhoh")
                }
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
                updateLoc(newloc: prop["loc"].asPropList!["Start"].asPoint!)
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
        let state = prop["state"].asString!
        if state != "hide" && state != "move2" {
            prop["state"] = .string("move2")
        }
    }

    func updateState(_ state: String, _ callback: LV = .void) {
        prop["callback"] = callback
        prop["state"] = .string(state)
    }

    func reportState() -> String {
        return prop["state"].asString!
    }

    func updateLoc(newloc: Point) {
        sprite(myNum).loc = newloc
        let sprites = prop["sprites"].asPropList!
        let keys = ["ouch", "but1", "but2", "but3"]
        for key in keys {
            sprite(sprites[key].asInt!).loc = sprite(myNum).loc
        }
        sprite(sprites["msg"].asInt!).loc = sprite(myNum).loc + Point(x: 77, y: 50)
    }

    func fixLocZ() {
        sprite(myNum).locZ = 1000000000
        let sprites = prop["sprites"].asPropList!
        for pair in sprites.props {
            sprite(pair.value.asInt!).locZ = 1000000001
        }
    }

    var spriteNum: Int { return myNum }
}
