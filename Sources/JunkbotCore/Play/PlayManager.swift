// Translated from Lingo: parent_play manager.ls

class PlayManager {
    var config: Any? = nil
    var playfield_manager: Any? = nil // PlayfieldManager
    var dragmember: Any? = nil
    var toolmode: String? = "#move"
    var movepart: Any? = nil
    var moveoffset: Point = Point(x: 0, y: 0)
    var mousestate: String = "#UP"
    var myactors: [Any] = []
    var myactorstime: [String: Any] = [:]
    var tracktime: Int = 0
    var reported_fieldpos: Any? = nil
    var gamestatus: [String: Any] = [:]
    var activeState: String = "#STANDBY"
    var movePieceGroup: Any? = nil
    var pressLoc: Point = Point(x: 0, y: 0)
    var pressPos: Any? = nil
    var goalList: [Any] = []
    var numGoals: Int = 0

    init() {
        activeState = "#STANDBY"
        toolmode = "#move"
        myactors = []
        goalList = []
        myactorstime = [:]
        tracktime = 0
        reported_fieldpos = nil
        // add(the actorList, me) -- stub: register in global actor list
    }

    func destroy() {
        leave()
        // deleteOne(the actorList, me) -- stub
    }

    func leave() {
        clearDragBricks()
        Glob.shared["partclick_recipient"] = nil
        activeState = "#STANDBY"
        setCursor("#none") // stub
        myactors = []
        // if playfield_manager != nil { playfield_manager.leave() }
        playfield_manager = nil
    }

    func refresh() {
        // setLevel(Glob.shared.EDITOR.edit_manager.playfield_manager.current_level) -- stub
    }

    func actorDone(_ a: AnyObject) {
        myactors.removeAll(where: { ($0 as AnyObject) === a })
        myactorstime.removeValue(forKey: ObjectIdentifier(a).debugDescription)
    }

    func setLevel(_ conf: Any?) {
        toolmode = "#move"
        // if ilk(conf) = #string then config = ... else config = conf
        if let confStr = conf as? String {
            // config = Glob.shared.config_manager.parseParams(confStr) -- stub
            config = confStr
        } else {
            config = conf
        }
        // playfield_manager = new PlayfieldManager(config.playfield) -- stub
        // playfield_manager.setPlayfield(config) -- stub
        // if config["info"] != nil { member("level title").text = ... } -- stub

        myactors = []
        // mytypes maps type symbols to script names; instantiate actors per type -- stub
        // goalList = playfield_manager.getPartsByType(["#flag"]) -- stub
        goalList = []
        numGoals = goalList.count
        gamestatus = ["#damage": 0, "#goals": 0, "#moves": 0]
        updateStatus()
        activeState = "#pause"
    }

    func startLevel() {
        Glob.shared["partclick_recipient"] = self
        activeState = "#Run"
    }

    func pauseLevel(_ flag: Bool) {
        if flag {
            Glob.shared["partclick_recipient"] = nil
            activeState = "#pause"
        } else {
            Glob.shared["partclick_recipient"] = self
            activeState = "#Run"
        }
    }

    func setdragsprite(_ opt: Any?) {
        // if Glob.shared.EDITOR["drag_sprite"] == nil { return } -- stub
        // ...drag sprite manipulation -- stub
        guard let optDict = opt as? [String: Any] else { return }
        _ = optDict["type"]
        _ = optDict["color"]
        dragmember = optDict["member"]
    }

    func instantWin() {
        // if Glob.shared["authorMode"] as? Int != 1 { return }
        guard Glob.shared["authorMode"] as? Int == 1 else { return }
    }

    func addStatus(_ p: String, _ d: Int) {
        switch p {
        case "#damage":
            SndSFX("die")
            activeState = "#pause"
            clearDragBricks()
            setCursor("#none")
            // Glob.shared.PLAYER.game_manager.endLevel("#LOSE")
            setCursor("#none")
        case "#goals":
            numGoals -= 1
            if numGoals == 0 {
                activeState = "#pause"
                clearDragBricks()
                setCursor("#none")
                // Glob.shared.PLAYER.game_manager.endLevel("#WIN")
                setCursor("#none")
            }
        default:
            break
        }
        if var val = gamestatus[p] as? Int {
            val += d
            gamestatus[p] = val
        }
        updateStatus()
    }

    func updateStatus() {
        var t = ""
        for (key, value) in gamestatus {
            t += "\(key): \(value)\n"
        }
        // member("play status field").text = t -- stub
        // member("play move counter field").text = String(gamestatus["#moves"] as? Int ?? 0) -- stub
        print(t)
    }

    func doSwitch(_ args: [String: Any]) {
        // repeat with part in playfield_manager.getPartsByLabel(args["label"]) { part.behavior.notify(["switch": args["state"]]) } -- stub
    }

    func clearDragBricks() {
        if let groups = movePieceGroup as? [[String: Any]] {
            for mp in groups {
                if let sprites = mp["sprite"] as? [AnyObject] {
                    for s in sprites {
                        // s.loc = Point(x: -200, y: -200) -- stub
                        _ = s
                    }
                }
            }
        }
    }

    func partclick(_ part: Any, _ evt: String) {
        switch evt {
        case "#mouseEnter":
            // reported_fieldpos = [part.pos, part.sprite[1].loc] -- stub
            break
        case "#mouseLeave":
            reported_fieldpos = nil
        default:
            break
        }
    }

    func stepFrame() {
        guard activeState == "#Run" else { return }
        // if Glob.shared.EDITOR["drag_sprite"] == nil { return } -- stub
        // if playfield_manager == nil { return } -- stub

        for a in myactors {
            let ms = Int(Date().timeIntervalSince1970 * 1000)
            // a.stepFrame() -- stub
            _ = a
            if tracktime != 0 {
                // myactorstime[a] = myactorstime[a] + milliSeconds - ms -- stub
                _ = ms
            }
        }

        if toolmode == nil {
            toolmode = "#move"
        }

        // Mouse state tracking (mouseDown stub)
        let mouseIsDown = false // stub: the mouseDown
        if mouseIsDown {
            if mousestate == "#UP" {
                mousestate = "#press"
            } else {
                mousestate = "#down"
            }
        } else {
            if mousestate == "#down" {
                mousestate = "#release"
            } else {
                mousestate = "#UP"
            }
        }

        // let ml = mouseLoc -- stub
        // let fieldpos = playfield_manager.getPos(ml) -- stub

        // toolmode switch omitted as it references many stubs (drag_sprite, playfield_manager, etc.)

        // if keyPressed(" ") && activeState == "#Run" { instantWin() }
    }

    func doPressing(_ ml: Point) {
        // temp["#down"] = playfield_manager.findPieceGroup(pressPos, "#down") -- stub
        // temp["#UP"] = playfield_manager.findPieceGroup(pressPos, "#UP") -- stub
        var dragDir: Any? = nil
        let pressOffSet = Point(x: ml.x - pressLoc.x, y: ml.y - pressLoc.y)
        // if pressOffSet.y > 3 or temp["#UP"] == [] { dragDir = "#down" }
        if pressOffSet.y > 3 {
            dragDir = "#down"
        }
        // if pressOffSet.y < -3 or temp["#down"] == [] { dragDir = "#UP" }
        if pressOffSet.y < -3 {
            dragDir = "#UP"
        }
        if dragDir == nil {
            if mousestate == "#release" {
                toolmode = "#move"
            }
        }
        if dragDir != nil {
            // movePieceGroup = temp[dragDir] -- stub
            // if movePieceGroup == [] { if abs(pressOffSet.y) > 20 { toolmode = "#move" } }
            // else { playfield_manager.erasePieceGroup(movePieceGroup, 1) ... toolmode = "#dragging" }
        }
    }
}
