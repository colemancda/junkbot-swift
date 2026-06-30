// Translated from Lingo: behavior_msgBox_Success.ls

class BehaviorMsgBoxSuccess {
    var prop: PropList = PropList()
    var myNum: Int = 0
    var keys: Int = 0

    func beginSprite() {
        Glob.shared["BIG_MSG_OBJ"] = .void  // set externally as object reference
        prop = PropList()
        prop["state"] = .string("hide")
        var loc = PropList()
        loc["Start"] = .point(x: 60, y: -280)
        loc["show"] = .point(x: 60, y: 80)
        loc["end"] = .point(x: -340, y: 80)
        prop["loc"] = .propList(loc)
        var speed = PropList()
        speed["move1"] = .list(LingoList([.int(0), .int(40)]))
        speed["move2"] = .list(LingoList([.int(-40), .int(0)]))
        prop["speed"] = .propList(speed)
        var sprites = PropList()
        sprites["MSG1"] = .int(myNum + 9)
        sprites["MSG2"] = .int(myNum + 10)
        sprites["MSG3"] = .int(myNum + 11)
        sprites["newrecord"] = .int(myNum + 2)
        sprites["gold"] = .int(myNum + 3)
        sprites["bicon"] = .int(myNum + 4)
        sprites["keys"] = .int(myNum + 8)
        prop["sprites"] = .propList(sprites)
        prop["todo"] = .list(LingoList())
    }

    func reportState() -> String {
        return prop["state"].asString!
    }

    func dropBox() {
        setCursor("none")
        sendAllSprites("getOut")
        prop["state"] = .string("move1")
        fixLocZ()
        updateData1()
    }

    func updateData1() {
        prop["todo"] = .list(LingoList())
        let current = Glob.shared["current"].asPropList!
        let building = current["building"].asInt!
        let level = current["level"].asInt!
        let moves = current["moves"].asInt!
        let buildingList = Glob.shared["building"].asList!
        let buildingEntry = buildingList[building].asPropList!
        let levelsLV = buildingEntry["LEVELS"]
        let levelsList = levelsLV.asList!
        let gold = levelsList[level]["gold"].asInt!
        if level > 15 {
            return
        }
        let sprites = prop["sprites"].asPropList!
        for x in 1...4 {
            let bEntry = buildingList[x].asPropList!
            let buildingState = bEntry["state"].asString!
            if buildingState == "open" {
                sprite(x + (sprites["bicon"].asInt! - 1)).member = member("building_icon_\(x)")
                updateStage()
            }
        }
        member("num.moves")?.text = String(moves)
        sprite(sprites["newrecord"].asInt!).blend = 0
        let data = levelsList
        keys = 0
        for i in 1...15 {
            let dataEntry = data[i].asPropList!
            if i == level {
                if (dataEntry["moves"].asInt ?? 0) > 0 {
                    member("msgbox_1")?.text = "KEYCARD ALREADY ACQUIRED"
                    sprite(myNum + 15).blend = 0
                } else {
                    member("msgbox_1")?.text = "YOU GOT A BUILDING \(building) KEYCARD"
                    sprite(myNum + 15).blend = 100
                    dataEntry["moves"] = .int(moves)
                }
                if moves < (dataEntry["moves"].asInt ?? 0) {
                    let todo = prop["todo"].asList!
                    todo.add(.string("newrecord"))
                    sprite(sprites["newrecord"].asInt!).blend = 100
                    dataEntry["moves"] = .int(moves)
                }
                if gold == 1 {
                    sprite(sprites["gold"].asInt!).blend = 100
                    member("msgbox_3")?.text = ""
                } else {
                    if (dataEntry["moves"].asInt ?? 0) <= (dataEntry["goal"].asInt ?? 0) {
                        buildingEntry["LEVELS"].asList![level]["gold"] = .int(1)
                        let todo = prop["todo"].asList!
                        todo.add(.string("goldaward"))
                        sprite(sprites["gold"].asInt!).blend = 100
                        member("msgbox_3")?.text = ""
                    } else {
                        member("msgbox_3")?.text = "beat this level in \(dataEntry["goal"].asInt!) moves or fewer\nto get the gold award"
                        sprite(sprites["gold"].asInt!).blend = 0
                    }
                }
            }
            if (dataEntry["moves"].asInt ?? 0) > 0 {
                keys += 1
            }
        }
        let keyrequired = Glob.shared["keyrequired"].asInt!
        if (keys >= keyrequired) && !(building == 4) && !(buildingList[building + 1]["state"].asString == "open") {
            member("msgbox_2")?.text = "YOU UNLOCKED BUILDING \(building + 1)"
            let todo = prop["todo"].asList!
            todo.add(.string("unlock"))
            buildingList[building + 1]["state"] = .string("open")
            SndSFX("unlock2")
        } else {
            if keys >= keyrequired {
                (Glob.shared["PLAYER"]).game_manager.TotalKeys()
                let rankdata = Glob.shared["rankdata"].asPropList!
                if (rankdata["keys"].asInt ?? 0) == 60 {
                    member("msgbox_2")?.text = ""
                } else {
                    member("msgbox_2")?.text = "GET ALL THE KEYCARDS!"
                }
            } else {
                if (keys < keyrequired) && !(building == 4) {
                    member("msgbox_2")?.text = "GET \(keyrequired - keys) MORE TO UNLOCK BUILDING \(building + 1)"
                } else {
                    member("msgbox_2")?.text = ""
                }
            }
        }
        if (level == 15) && (keys >= keyrequired) && !(current["building"].asInt == 4) {
            sprite(myNum + 13).blend = 100
            sprite(myNum + 13).member = member("but_next_bd")
            updateStage()
            sprite(myNum + 13).updateProp()
        } else {
            if (level == 15) && (keys >= keyrequired) && (current["building"].asInt == 4) {
                sprite(myNum + 13).blend = 0
            } else {
                sprite(myNum + 13).blend = 100
            }
        }
        makekey(keys: keys)
    }

    func exitFrame() {
        let current = Glob.shared["current"].asPropList!
        let building = current["building"].asInt!
        let sprites = prop["sprites"].asPropList!
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
            let todo = prop["todo"].asList!
            if todo.getOne(.string("unlock")) {
                if building < 4 {
                    let bsp = sprite(sprites["bicon"].asInt! + building)
                    for _ in 1...10 {
                        bsp.blend -= 5
                        updateStage()
                    }
                    for _ in 1...10 {
                        bsp.blend += 5
                        updateStage()
                    }
                    bsp.member = member("building_icon_\(building + 1)")
                }
            }
            if todo.getOne(.string("goldaward")) {
                let bsp = sprite(sprites["gold"].asInt!)
                bsp.blend = 100
                updateStage()
            }
            if todo.getOne(.string("newrecord")) {
                let bsp = sprite(sprites["newrecord"].asInt!)
                bsp.blend = 100
                updateStage()
            }
            prop["state"] = .string("showdone")
        case "move2":
            let locEnd = prop["loc"]["end"].asPoint!
            let speedList = prop["speed"]["move2"].asList!
            let spd = [speedList[1].asInt!, speedList[2].asInt!]
            let temp = doMove(toWhere: locEnd, speed: spd)
            if temp != 0 {
                prop["state"] = .string("hide")
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
            sprite(myNum + sn).visible = true
        }
    }

    func makekey(keys: Int) {
        // Image compositing stub — sets up key icon strip
        // member("mem_keys").image = image(400, 20, 8)
        // Copies key icons side-by-side into mem_keys member
    }
}
