// Translated from Lingo: parent_edit manager.ls

class EditManager {
    var config: [String: Any] = [String: Any]()
    var playfield_manager: PlayfieldManager? = nil
    var toolmode: String = "none"
    var toolparam: String? = nil
    var toolcolor: String = "GRAY"
    var currenttool_toolcolor: String? = nil
    var toolstate: String? = nil
    var toolframe: Int? = nil
    var dragpart: [String: Any]? = nil
    var movepart: [String: Any]? = nil
    var moveoffset: Point = Point(x: 0, y: 0)
    var mousestate: String = "UP"

    init() {
        self.setConfig()
        if let pfConf = config["playfield"] {
            playfield_manager = PlayfieldManager(pfConf)
        }
        actorList.append(self)
        toolmode = "none"
        toolparam = nil
        toolcolor = "GRAY"
    }

    func destroy() {
        leave()
        actorList.removeAll { $0 === self }
    }

    func leave() {
        playfield_manager?.setInfo([
            "title": field("catalog title"),
            "par": field("editor par field"),
            "hint": field("editor hint field")
        ])
        let currentLevel = playfield_manager?.toString() ?? ""
        glob.PLAYER.game_manager.setGame([currentLevel])
        setCursor("none")
        playfield_manager?.leave()
    }

    func refresh() {
        playfield_manager?.refresh()
        let info = playfield_manager?.getInfo()
        if info != nil {
            member("catalog title").text = String(describing: info?["title"] ?? "")
            member("catalog par").text = String(describing: info?["par"] ?? "")
            member("catalog hint").text = String(describing: info?["hint"] ?? "")
        } else {
            member("catalog title").text = ""
            member("catalog par").text = ""
            member("catalog hint").text = ""
        }
        settoolmode(toolmode, toolparam, toolstate, toolframe ?? 0)
    }

    func setConfig() {
        let configtext = member("config field").text
        config = glob["config_manager"].parseParams(configtext)
        if playfield_manager != nil {
            playfield_manager?.setConfig(config["playfield"])
        }
    }

    func settoolmode(_ m: String, _ p: String?, _ s: String?, _ f: Int) {
        toolmode = m
        toolparam = p
        toolstate = s
        toolframe = f
        switch toolmode {
        case "move":
            setCursor("grab")
            setdragsprite("reset")
        case "erase":
            setCursor("eraser")
            setdragsprite("reset")
        case "place":
            setCursor("none")
            setdragsprite(["type": toolparam as Any, "color": toolcolor, "state": toolstate as Any, "frame": f])
        default:
            setCursor("none")
        }
    }

    func settoolcolor(_ c: String) {
        toolcolor = c
        if glob.EDITOR["drag_sprite"] != nil, toolparam != nil {
            setdragsprite(["color": toolcolor])
        }
    }

    func bg_edit_item(_ kind: String, _ mem: Member?) {
        switch kind {
        case "backdrop":
            playfield_manager?.setBackdrop(mem?.name ?? "")
        case "decal":
            toolmode = "place_decal"
            let dragmember = mem
            glob.EDITOR.drag_sprite.member = dragmember
            glob.EDITOR.drag_sprite.rect = dragmember?.rect
            glob.EDITOR.drag_sprite.ink = 36
            glob.EDITOR.drag_sprite.locZ = 200
            setCursor("none")
        default:
            break
        }
    }

    func setdragsprite(_ opt: Any) {
        guard glob.EDITOR["drag_sprite"] != nil else { return }
        glob.EDITOR.drag_sprite.puppet = 1
        glob.EDITOR.drag_sprite.ink = 36
        if let optStr = opt as? String, optStr == "reset" {
            glob.EDITOR.drag_sprite.loc = Point(x: -100, y: -100)
            glob.EDITOR.drag_sprite.blend = 100
            dragpart = nil
            return
        } else if let optDict = opt as? [String: Any] {
            if optDict["type"] != nil {
                dragpart = optDict
            } else {
                if dragpart != nil {
                    dragpart?["color"] = optDict["color"]
                }
            }
        } else {
            return
        }
        if dragpart != nil {
            let dragmembername = glob.legoparts_manager.getPieceMemberName(dragpart!, "single")
            let dragmember = member(dragmembername)
            glob.EDITOR.drag_sprite.member = dragmember
            glob.EDITOR.drag_sprite.width = (glob.EDITOR.drag_sprite.member?.width ?? 0) * (playfield_manager?.pf_scale ?? 1)
            glob.EDITOR.drag_sprite.height = (glob.EDITOR.drag_sprite.member?.height ?? 0) * (playfield_manager?.pf_scale ?? 1)
        }
    }

    func stepFrame() {
        guard frame == marker("edit") else { return }
        if mouseDown {
            if mousestate == "UP" {
                mousestate = "press"
            } else {
                mousestate = "down"
            }
        } else {
            if mousestate == "down" {
                mousestate = "release"
            } else {
                mousestate = "UP"
            }
        }
        var ml = mouseLoc
        if toolmode == "moving" {
            ml = ml + moveoffset
        }
        let fieldpos = playfield_manager?.getPos(ml)
        if glob.EDITOR["drag_sprite"] != nil {
            switch toolmode {
            case "place":
                if fieldpos == nil {
                    glob.EDITOR.drag_sprite.loc = Point(x: -100, y: -100)
                } else {
                    glob.EDITOR.drag_sprite.loc = fieldpos![1] as? Point
                    let row = (fieldpos![0] as? [Int])?[1] ?? 0
                    let col = (fieldpos![0] as? [Int])?[0] ?? 0
                    glob.EDITOR.drag_sprite.locZ = 100000 - (1000 * row) + 999
                    if playfield_manager?.checkFit(fieldpos![0], toolparam ?? "") == true {
                        glob.EDITOR.drag_sprite.blend = 100
                        if mousestate == "press" {
                            dragpart?["pos"] = fieldpos![0]
                            var tpart = dragpart
                            let partType = tpart?["type"] as? String ?? ""
                            if (partType == "HAZ_SLICKSWITCH" || partType == "HAZ_SLICKFIRE" || partType == "HAZ_SLICKFAN"),
                               tpart?["label"] == nil {
                                tpart?["label"] = "switch1"
                            }
                            if let tpart = tpart {
                                playfield_manager?.placePiece(tpart)
                            }
                        }
                    } else {
                        glob.EDITOR.drag_sprite.blend = 30
                    }
                }
            case "config":
                if mousestate == "press" {
                    if fieldpos != nil {
                        var tpart = playfield_manager?.getPart(fieldpos![0])
                        if tpart == nil {
                            field("part inspector field").text = ""
                        } else {
                            tpart = tpart?.duplicate()
                            tpart?.removeValue(forKey: "sprite")
                            let tpos = tpart?["pos"]
                            tpart?.removeValue(forKey: "pos")
                            tpart?["tpos"] = [tpos?[0], tpos?[1]]
                            let partType = tpart?["type"] as? String ?? ""
                            switch partType {
                            case "HAZ_SLICKSWITCH", "HAZ_SLICKFIRE", "HAZ_SLICKFAN":
                                if tpart?["label"] == nil {
                                    tpart?["label"] = "switch1"
                                }
                            default:
                                break
                            }
                            field("part inspector field").text = glob.config_manager.toString(["part": tpart as Any])
                        }
                    }
                }
            case "moving":
                if fieldpos == nil {
                    glob.EDITOR.drag_sprite.loc = Point(x: -100, y: -100)
                } else {
                    glob.EDITOR.drag_sprite.loc = fieldpos![1] as? Point
                    let row = (fieldpos![0] as? [Int])?[1] ?? 0
                    glob.EDITOR.drag_sprite.locZ = 100000 - (1000 * row) + 999
                    let mpType = movepart?["type"] as? String ?? ""
                    if playfield_manager?.checkFit(fieldpos![0], mpType) == true {
                        glob.EDITOR.drag_sprite.blend = 100
                        if mousestate == "press" || (toolmode == "moving" && mousestate == "release") {
                            dragpart?["pos"] = fieldpos![0]
                            let tpart = dragpart
                            if let tpart = tpart {
                                playfield_manager?.placePiece(tpart)
                            }
                            if toolmode == "moving" {
                                toolmode = "move"
                            }
                            setdragsprite("reset")
                        }
                    } else {
                        glob.EDITOR.drag_sprite.blend = 30
                    }
                }
            case "erase":
                if fieldpos != nil && mousestate == "release" {
                    let tmppart = playfield_manager?.erasePiece(fieldpos![0])
                    if tmppart == nil {
                        playfield_manager?.eraseDecal(mouseLoc)
                    }
                }
            case "move":
                if mousestate == "press", fieldpos != nil {
                    movepart = playfield_manager?.erasePiece(fieldpos![0])
                    if movepart == nil {
                        let decal = playfield_manager?.eraseDecal(mouseLoc)
                        if decal == nil {
                            setdragsprite("reset")
                        } else {
                            bg_edit_item("decal", decal?["member"] as? Member)
                            toolmode = "place_decal"
                            glob.EDITOR.drag_sprite.locZ = 200
                        }
                    } else {
                        let mpPos = movepart?["pos"]
                        let abovePos = offsetPoint(mpPos, dy: -1)
                        moveoffset = (playfield_manager?.getLoc(abovePos) ?? Point(x: 0, y: 0)) - ml
                        setdragsprite(movepart!)
                        glob.EDITOR.drag_sprite.loc = playfield_manager?.getLoc(movepart?["pos"])
                        let row = (fieldpos![0] as? [Int])?[1] ?? 0
                        glob.EDITOR.drag_sprite.locZ = 100000 - (1000 * row) + 999
                        toolmode = "moving"
                    }
                }
            case "place_decal":
                glob.EDITOR.drag_sprite.loc = mouseLoc
                glob.EDITOR.drag_sprite.blend = 100
                glob.EDITOR.drag_sprite.locZ = 200
                if mousestate == "release", fieldpos != nil {
                    playfield_manager?.placeDecal(["loc": glob.EDITOR.drag_sprite.loc as Any, "member": glob.EDITOR.drag_sprite.member as Any])
                    toolmode = "move"
                    setdragsprite("reset")
                }
            default:
                break
            }
        }
    }

    func doConfigPart(_ part_text: String) {
        var newpart = glob.config_manager.parseParams(part_text)["part"] as? [String: Any] ?? [String: Any]()
        let tpos = newpart["tpos"] as? [Int] ?? [0, 0]
        newpart["pos"] = Point(x: tpos[0], y: tpos[1])
        newpart.removeValue(forKey: "tpos")
        if let pos = newpart["pos"] {
            playfield_manager?.erasePiece(pos)
        }
        playfield_manager?.placePiece(newpart)
    }
}
