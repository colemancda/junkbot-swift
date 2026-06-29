// Translated from Lingo: parent_play manager.ls

public class PlayManager {
    public var config: LV = .void
    public var playfield_manager: LV = .void
    public var dragmember: LV = .void
    public var toolmode: String = "#move"
    public var movepart: LV = .void
    public var moveoffset: Point = Point()
    public var mousestate: String = "#UP"
    public var myactors: [AnyObject] = []
    public var myactorstime: PropList = PropList()
    public var tracktime: Int = 0
    public var reported_fieldpos: LV = .void
    public var gamestatus: PropList = PropList()
    public var activeState: String = "#STANDBY"
    public var movePieceGroup: LV = .void
    public var pressLoc: Point = Point()
    public var pressPos: LV = .void
    public var goalList: [LV] = []
    public var numGoals: Int = 0

    public init() {
        activeState = "#STANDBY"
        toolmode = "#move"
        myactors = []
        goalList = []
        myactorstime = PropList()
        tracktime = 0
        reported_fieldpos = .void
        // add(the actorList, me) -- stub: register in global actor list
    }

    public func destroy() {
        leave()
        // deleteOne(the actorList, me) -- stub
    }

    public func leave() {
        clearDragBricks()
        Glob.shared["partclick_recipient"] = .void
        activeState = "#STANDBY"
        setCursor("#none")
        myactors = []
        // if playfield_manager != nil { playfield_manager.leave() }
        playfield_manager = .void
    }

    public func refresh() {
        // setLevel(Glob.shared.EDITOR.edit_manager.playfield_manager.current_level) -- stub
    }

    public func actorDone(_ a: AnyObject) {
        myactors.removeAll(where: { $0 === a })
    }

    public func setLevel(_ conf: LV) {
        toolmode = "#move"
        if conf.isString {
            // config = Glob.shared.config_manager.parseParams(confStr) -- stub
            config = conf
        } else {
            config = conf
        }
        // playfield_manager = new PlayfieldManager(config.playfield) -- stub
        // playfield_manager.setPlayfield(config) -- stub
        // if config["info"] != nil { member("level title").text = ... } -- stub

        myactors = []
        goalList = []
        numGoals = goalList.count
        gamestatus = PropList()
        gamestatus["#damage"] = .int(0)
        gamestatus["#goals"] = .int(0)
        gamestatus["#moves"] = .int(0)
        updateStatus()
        activeState = "#pause"
    }

    public func startLevel() {
        Glob.shared["partclick_recipient"] = .void  // stub: store self reference
        activeState = "#Run"
    }

    public func pauseLevel(_ flag: Bool) {
        if flag {
            Glob.shared["partclick_recipient"] = .void
            activeState = "#pause"
        } else {
            Glob.shared["partclick_recipient"] = .void  // stub: store self reference
            activeState = "#Run"
        }
    }

    public func setdragsprite(_ opt: PropList?) {
        guard let opt = opt else { return }
        dragmember = opt["member"]
    }

    public func instantWin() {
        guard Glob.shared["authorMode"].asInt == 1 else { return }
    }

    public func addStatus(_ p: String, _ d: Int) {
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
        if let val = gamestatus[p].asInt {
            gamestatus[p] = .int(val + d)
        }
        updateStatus()
    }

    public func updateStatus() {
        var t = ""
        for prop in gamestatus.props {
            t += "\(prop.key): \(prop.value)\n"
        }
        // member("play status field").text = t -- stub
        // member("play move counter field").text = String(gamestatus["#moves"].asInt ?? 0) -- stub
        debugLog(t)
    }

    public func doSwitch(_ args: PropList) {
        // repeat with part in playfield_manager.getPartsByLabel(args["label"]) { part.behavior.notify(["switch": args["state"]]) } -- stub
    }

    public func clearDragBricks() {
        // movePieceGroup sprite manipulation -- stub
    }

    public func partclick(_ part: LV, _ evt: String) {
        switch evt {
        case "#mouseEnter":
            // reported_fieldpos = [part.pos, part.sprite[1].loc] -- stub
            break
        case "#mouseLeave":
            reported_fieldpos = .void
        default:
            break
        }
    }

    public func stepFrame() {
        guard activeState == "#Run" else { return }
        // if Glob.shared.EDITOR["drag_sprite"] == nil { return } -- stub
        // if playfield_manager == nil { return } -- stub

        for _ in myactors {
            let ms = currentMilliseconds
            // a.stepFrame() -- stub
            if tracktime != 0 {
                _ = ms
            }
        }

        if toolmode.isEmpty {
            toolmode = "#move"
        }

        // Mouse state tracking
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

    public func doPressing(_ ml: Point) {
        // temp["#down"] = playfield_manager.findPieceGroup(pressPos, "#down") -- stub
        // temp["#UP"] = playfield_manager.findPieceGroup(pressPos, "#UP") -- stub
        var dragDir: String? = nil
        let pressOffSet = Point(x: ml.x - pressLoc.x, y: ml.y - pressLoc.y)
        if pressOffSet.y > 3 {
            dragDir = "#down"
        }
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
