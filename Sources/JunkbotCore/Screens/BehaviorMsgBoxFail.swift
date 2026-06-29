// Translated from Lingo: behavior_msgBox_Fail.ls

class BehaviorMsgBoxFail {
    var prop: [String: Any] = [:]
    var myNum: Int = 0

    func beginSprite() {
        myNum = spriteNum
        glob["fail_msg_obj"] = self
        prop = [:]
        prop["state"] = "hide"
        prop["loc"] = ["Start": Point(x: 100, y: -190), "show": Point(x: 100, y: 130), "end": Point(x: -300, y: 130)]
        prop["speed"] = ["move1": [0, 40], "move2": [-40, 0]]
        prop["sprites"] = ["ouch": myNum + 1, "but1": myNum + 2, "but2": myNum + 3, "but3": myNum + 4, "msg": myNum + 5]
    }

    func updateData() {
        let msg = ["I hate Mondays.", "I knew that was going to happen.", "Why me?", "There's got to be a better way."]
        member("fail_msg").text = msg[Int.random(in: 1...msg.count) - 1]
        setCursor("none")
        sendAllSprites("getOut")
        prop["state"] = "move1"
        fixLocZ()
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
                if Int.random(in: 1...2) == 1 {
                    SndSFX("voice_ouch")
                } else {
                    SndSFX("voice_uhoh")
                }
            }
        case "show":
            setCursor("none")
        case "move2":
            let locEnd = (prop["loc"] as! [String: Any])["end"] as! Point
            let speedMove2 = (prop["speed"] as! [String: Any])["move2"] as! [Int]
            let temp = doMove(toWhere: locEnd, speed: speedMove2)
            if temp != 0 {
                prop["state"] = "hide"
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

    func getOut() {
        let state = prop["state"] as! String
        if state != "hide" && state != "move2" {
            prop["state"] = "move2"
        }
    }

    func updateState(_ state: String, _ callback: Any? = nil) {
        prop["callback"] = callback
        prop["state"] = state
    }

    func reportState() -> String {
        return prop["state"] as! String
    }

    func updateLoc(newloc: Point) {
        sprite(myNum).loc = newloc
        let sprites = prop["sprites"] as! [String: Int]
        for sn in 1...4 {
            let key = ["ouch", "but1", "but2", "but3"][sn - 1]
            sprite(sprites[key]!).loc = sprite(myNum).loc
        }
        sprite(sprites["msg"]!).loc = sprite(myNum).loc + Point(x: 77, y: 50)
    }

    func fixLocZ() {
        sprite(myNum).locZ = 1000000000
        let sprites = prop["sprites"] as! [String: Int]
        for sn in sprites.values {
            sprite(sn).locZ = 1000000001
        }
    }

    var spriteNum: Int { return myNum }
}
