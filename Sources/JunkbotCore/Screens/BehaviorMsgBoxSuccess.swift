// Translated from Lingo: behavior_msgBox_Success.ls

class BehaviorMsgBoxSuccess {
    var prop: [String: Any] = [:]
    var myNum: Int = 0
    var keys: Int = 0

    func beginSprite() {
        glob["BIG_MSG_OBJ"] = self
        prop = [:]
        prop["state"] = "hide"
        prop["loc"] = ["Start": Point(x: 60, y: -280), "show": Point(x: 60, y: 80), "end": Point(x: -340, y: 80)]
        prop["speed"] = ["move1": [0, 40], "move2": [-40, 0]]
        prop["sprites"] = [
            "MSG1": myNum + 9, "MSG2": myNum + 10, "MSG3": myNum + 11,
            "newrecord": myNum + 2, "gold": myNum + 3, "bicon": myNum + 4, "keys": myNum + 8
        ]
        prop["todo"] = [String]()
    }

    func reportState() -> String {
        return prop["state"] as! String
    }

    func dropBox() {
        setCursor("none")
        sendAllSprites("getOut")
        prop["state"] = "move1"
        fixLocZ()
        updateData1()
    }

    func updateData1() {
        prop["todo"] = [String]()
        let building = (glob["current"] as! [String: Any])["building"] as! Int
        let level = (glob["current"] as! [String: Any])["level"] as! Int
        let moves = (glob["current"] as! [String: Any])["moves"] as! Int
        let gold = ((glob["building"] as! [[String: Any]])[building - 1]["LEVELS"] as! [[String: Any]])[level - 1]["gold"] as! Int
        if level > 15 {
            return
        }
        let sprites = prop["sprites"] as! [String: Int]
        for x in 1...4 {
            let buildingState = (glob["building"] as! [[String: Any]])[x - 1]["state"] as! String
            if buildingState == "open" {
                sprite(x + (sprites["bicon"]! - 1)).member = member("building_icon_\(x)")
                updateStage()
            }
        }
        member("num.moves").text = String(moves)
        var flag = 0
        sprite(sprites["newrecord"]!).blend = 0
        var data = (glob["building"] as! [[String: Any]])[building - 1]["LEVELS"] as! [[String: Any]]
        keys = 0
        for i in 1...15 {
            if i == level {
                if (data[i - 1]["moves"] as! Int) > 0 {
                    member("msgbox_1").text = "KEYCARD ALREADY ACQUIRED"
                    sprite(myNum + 15).blend = 0
                } else {
                    member("msgbox_1").text = "YOU GOT A BUILDING \(building) KEYCARD"
                    sprite(myNum + 15).blend = 100
                    data[i - 1]["moves"] = moves
                }
                if moves < (data[i - 1]["moves"] as! Int) {
                    var todo = prop["todo"] as! [String]
                    todo.append("newrecord")
                    prop["todo"] = todo
                    sprite(sprites["newrecord"]!).blend = 100
                    data[i - 1]["moves"] = moves
                }
                if gold == 1 {
                    sprite(sprites["gold"]!).blend = 100
                    member("msgbox_3").text = ""
                } else {
                    if (data[i - 1]["moves"] as! Int) <= (data[i - 1]["goal"] as! Int) {
                        var buildingLevels = (glob["building"] as! [[String: Any]])[building - 1]["LEVELS"] as! [[String: Any]]
                        buildingLevels[level - 1]["gold"] = 1
                        var todo = prop["todo"] as! [String]
                        todo.append("goldaward")
                        prop["todo"] = todo
                        sprite(sprites["gold"]!).blend = 100
                        member("msgbox_3").text = ""
                    } else {
                        member("msgbox_3").text = "beat this level in \(data[i - 1]["goal"]!) moves or fewer\nto get the gold award"
                        sprite(sprites["gold"]!).blend = 0
                    }
                }
            }
            if (data[i - 1]["moves"] as! Int) > 0 {
                keys += 1
            }
        }
        let keyrequired = glob["keyrequired"] as! Int
        if (keys >= keyrequired) && !(building == 4) && !((glob["building"] as! [[String: Any]])[building]["state"] as! String == "open") {
            member("msgbox_2").text = "YOU UNLOCKED BUILDING \(building + 1)"
            var todo = prop["todo"] as! [String]
            todo.append("unlock")
            prop["todo"] = todo
            var buildingArr = glob["building"] as! [[String: Any]]
            buildingArr[building]["state"] = "open"
            glob["building"] = buildingArr
            SndSFX("unlock2")
        } else {
            if keys >= keyrequired {
                (glob["PLAYER"] as AnyObject).game_manager.TotalKeys()
                let rankdata = glob["rankdata"] as! [String: Any]
                if (rankdata["keys"] as! Int) == 60 {
                    member("msgbox_2").text = ""
                } else {
                    member("msgbox_2").text = "GET ALL THE KEYCARDS!"
                }
            } else {
                if (keys < keyrequired) && !(building == 4) {
                    member("msgbox_2").text = "GET \(keyrequired - keys) MORE TO UNLOCK BUILDING \(building + 1)"
                } else {
                    member("msgbox_2").text = ""
                }
            }
        }
        if (level == 15) && (keys >= keyrequired) && !((glob["current"] as! [String: Any])["building"] as! Int == 4) {
            sprite(myNum + 13).blend = 100
            sprite(myNum + 13).member = member("but_next_bd")
            updateStage()
            sprite(myNum + 13).updateProp()
        } else {
            if (level == 15) && (keys >= keyrequired) && ((glob["current"] as! [String: Any])["building"] as! Int == 4) {
                sprite(myNum + 13).blend = 0
            } else {
                sprite(myNum + 13).blend = 100
            }
        }
        makekey(keys: keys)
    }

    func exitFrame() {
        let building = (glob["current"] as! [String: Any])["building"] as! Int
        let sprites = prop["sprites"] as! [String: Int]
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
            let todo = prop["todo"] as! [String]
            if todo.firstIndex(of: "unlock") != nil {
                if building < 4 {
                    let bsp = sprite(sprites["bicon"]! + building)
                    for _ in 1...10 {
                        bsp.rect = bsp.rect + Rect(left: -1, top: -1, right: 1, bottom: 1)
                        bsp.blend -= 5
                        updateStage()
                    }
                    for _ in 1...10 {
                        bsp.rect = bsp.rect + Rect(left: 1, top: 1, right: -1, bottom: -1)
                        bsp.blend += 5
                        updateStage()
                    }
                    bsp.stretch = 0
                    updateStage()
                    bsp.member = member("building_icon_\(building + 1)")
                }
            }
            if todo.firstIndex(of: "goldaward") != nil {
                let bsp = sprite(sprites["gold"]!)
                bsp.blend = 100
                updateStage()
            }
            if todo.firstIndex(of: "newrecord") != nil {
                let bsp = sprite(sprites["newrecord"]!)
                bsp.blend = 100
                updateStage()
            }
            prop["state"] = "showdone"
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

    func updateLoc(newloc: Point) {
        sprite(myNum).loc = newloc
        for sn in 1...3 {
            sprite(myNum + sn).loc = sprite(myNum).loc
        }
        sprite(myNum + 4).loc = sprite(myNum).loc + Point(x: 52, y: 177) + Point(x: 30, y: -19)
        sprite(myNum + 5).loc = sprite(myNum).loc + Point(x: 136, y: 177) + Point(x: 29, y: -14)
        sprite(myNum + 6).loc = sprite(myNum).loc + Point(x: 217, y: 177) + Point(x: 31, y: -17)
        sprite(myNum + 7).loc = sprite(myNum).loc + Point(x: 301, y: 177) + Point(x: 28, y: -21)
        sprite(myNum + 8).loc = sprite(myNum).loc + Point(x: 26, y: 75)
        sprite(myNum + 15).loc = sprite(myNum).loc + Point(x: 26, y: 75) + Point(x: (keys - 1) * 24, y: 0)
        sprite(myNum + 9).loc = sprite(myNum).loc + Point(x: 33, y: 49)
        sprite(myNum + 10).loc = sprite(myNum).loc + Point(x: 25, y: 96)
        sprite(myNum + 11).loc = sprite(myNum).loc + Point(x: 35, y: 214)
        sprite(myNum + 12).loc = sprite(myNum).loc + Point(x: 100, y: 188)
        sprite(myNum + 13).loc = sprite(myNum).loc + Point(x: 334, y: 236)
        sprite(myNum + 14).loc = sprite(myNum).loc + Point(x: 334, y: 207)
    }

    func fixLocZ() {
        sprite(myNum).locZ = 1000000000
        for sn in 1...17 {
            sprite(myNum + sn).locZ = 1000000001 + sn
            sprite(myNum + sn).blend = 100
            sprite(myNum + sn).visible = 1
        }
    }

    func makekey(keys: Int) {
        // Image compositing stub — sets up key icon strip
        // member("mem_keys").image = image(400, 20, 8)
        // Copies key icons side-by-side into mem_keys member
    }
}
