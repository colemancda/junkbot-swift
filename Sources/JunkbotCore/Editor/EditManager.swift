// Translated from Lingo: parent_edit manager.ls

class EditManager: LingoObject, @unchecked Sendable {
    var config: PropList = PropList()
    var playfield_manager: PlayfieldManager? = nil
    var toolmode: String = "none"
    var toolparam: String? = nil
    var toolcolor: String = "GRAY"
    var currenttool_toolcolor: String? = nil
    var toolstate: String? = nil
    var toolframe: Int? = nil
    var dragpart: PropList? = nil
    var movepart: PropList? = nil
    var moveoffset: Point = Point(x: 0, y: 0)
    var mousestate: String = "UP"

    override init() {
        super.init()
        self.setConfig()
        if !config["playfield"].isVoid {
            playfield_manager = PlayfieldManager(config["playfield"])
        }
        actorList.append(self as LingoObject)
        toolmode = "none"
        toolparam = nil
        toolcolor = "GRAY"
    }

    func destroy() {
        leave()
        actorList.removeAll { $0 === self }
    }

    func leave() {
        var infoList = PropList()
        infoList["title"] = .string(member("catalog title")?.text ?? "")
        infoList["par"] = .string(member("editor par field")?.text ?? "")
        infoList["hint"] = .string(member("editor hint field")?.text ?? "")
        playfield_manager?.setInfo(infoList)
        let currentLevel = playfield_manager?.toString() ?? ""
        glob.PLAYER.game_manager.setGame(.list(LingoList([.string(currentLevel)])))
        setCursor("none")
        playfield_manager?.leave()
    }

    func refresh() {
        playfield_manager?.refresh()
        if let info = playfield_manager?.getInfo() {
            member("catalog title")?.text = info["title"].asString ?? ""
            member("catalog par")?.text = info["par"].asString ?? ""
            member("catalog hint")?.text = info["hint"].asString ?? ""
        } else {
            member("catalog title")?.text = ""
            member("catalog par")?.text = ""
            member("catalog hint")?.text = ""
        }
        settoolmode(toolmode, toolparam, toolstate, toolframe ?? 0)
    }

    func setConfig() {
        let configtext = member("config field")?.text
        config = glob.config_manager.parseParams(configtext ?? "")
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
            setdragsprite(.string("reset"))
        case "erase":
            setCursor("eraser")
            setdragsprite(.string("reset"))
        case "place":
            setCursor("none")
            var optDict = PropList()
            optDict["type"] = toolparam.map { .string($0) } ?? .void
            optDict["color"] = .string(toolcolor)
            optDict["state"] = toolstate.map { .string($0) } ?? .void
            optDict["frame"] = .int(f)
            setdragsprite(.propList(optDict))
        default:
            setCursor("none")
        }
    }

    func settoolcolor(_ c: String) {
        toolcolor = c
        if !glob.EDITOR["drag_sprite"].isVoid, toolparam != nil {
            var optDict = PropList()
            optDict["color"] = .string(toolcolor)
            setdragsprite(.propList(optDict))
        }
    }

    func bg_edit_item(_ kind: String, _ mem: LingoMember?) {
        switch kind {
        case "backdrop":
            playfield_manager?.setBackdrop(.string(mem?.name ?? ""))
        case "decal":
            toolmode = "place_decal"
            let dragmember = mem
            glob.EDITOR.drag_sprite.member = dragmember.map { .object($0 as LingoObject) } ?? .void
            glob.EDITOR.drag_sprite.rect = dragmember.map { .object($0 as LingoObject) } ?? .void
            glob.EDITOR.drag_sprite.ink = 36
            glob.EDITOR.drag_sprite.locZ = 200
            setCursor("none")
        default:
            break
        }
    }

    func setdragsprite(_ opt: LV) {
        guard !glob.EDITOR["drag_sprite"].isVoid else { return }
        glob.EDITOR.drag_sprite.puppet = 1
        glob.EDITOR.drag_sprite.ink = 36
        if let optStr = opt.asString, optStr == "reset" {
            // // glob.EDITOR.drag_sprite.loc = Point // skip LV Point(x: -100, y: -100) // Point not LV
            glob.EDITOR.drag_sprite.blend = 100
            dragpart = nil
            return
        } else if let optDict = opt.asPropList {
            if !optDict["type"].isVoid {
                dragpart = optDict
            } else {
                if dragpart != nil {
                    dragpart?["color"] = optDict["color"]
                }
            }
        } else {
            return
        }
        if let dp = dragpart {
            let dragmembername = glob.legoparts_manager.getPieceMemberName(part: dp, single: "single").asString ?? ""
            let dragmember = member(dragmembername)
            glob.EDITOR.drag_sprite.member = dragmember.map { LV.object($0) } ?? .void
            glob.EDITOR.drag_sprite.width = .int(dragmember?.width ?? 0)
            glob.EDITOR.drag_sprite.height = .int(dragmember?.height ?? 0)
        }
    }

    func stepFrame() {
        // guard frame == marker("edit") else { return }
        if mouseIsDown {
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
        if !glob.EDITOR["drag_sprite"].isVoid {
            switch toolmode {
            case "place":
                if fieldpos == nil {
                    // // glob.EDITOR.drag_sprite.loc = Point // skip LV Point(x: -100, y: -100) // Point not LV
                } else {
                    if let pt = fieldpos![1].asPoint {
                        // glob.EDITOR.drag_sprite.loc = pt // skip LV Point
                    }
                    let row = fieldpos![0].asPoint?.y ?? 0
                    let col = fieldpos![0].asPoint?.x ?? 0
                    glob.EDITOR.drag_sprite.locZ = .int(100000 - (1000 * row) + 999)
                    if playfield_manager?.checkFit(fieldpos![0], toolparam ?? "") == true {
                        glob.EDITOR.drag_sprite.blend = 100
                        if mousestate == "press" {
                            dragpart?["pos"] = fieldpos![0]
                            if let dp = dragpart {
                                let partType = dp["type"].asString ?? ""
                                if (partType == "HAZ_SLICKSWITCH" || partType == "HAZ_SLICKFIRE" || partType == "HAZ_SLICKFAN"),
                                   dp["label"].isVoid {
                                    dragpart?["label"] = .string("switch1")
                                }
                                playfield_manager?.placePiece(dragpart!)
                            }
                        }
                    } else {
                        glob.EDITOR.drag_sprite.blend = 30
                    }
                }
            case "config":
                if mousestate == "press" {
                    if let fp = fieldpos {
                        var tpart = playfield_manager?.getPart(fp[0])
                        if tpart == nil {
                            member("part inspector field")?.text = ""
                        } else {
                            tpart = tpart?.duplicate()
                            tpart?.deleteOne("sprite")
                            let tpos = tpart?["pos"]
                            tpart?.deleteOne("pos")
                            if let pt = tpos?.asPoint {
                                let tposArr = LingoList()
                                tposArr.add(.int(pt.x))
                                tposArr.add(.int(pt.y))
                                tpart?["tpos"] = .list(tposArr)
                            }
                            if let tp = tpart {
                                let partType = tp["type"].asString ?? ""
                                switch partType {
                                case "HAZ_SLICKSWITCH", "HAZ_SLICKFIRE", "HAZ_SLICKFAN":
                                    if tp["label"].isVoid {
                                        tpart?["label"] = .string("switch1")
                                    }
                                default:
                                    break
                                }
                                var wrapper = PropList()
                                wrapper["part"] = .propList(tp)
                                member("part inspector field")?.text = glob.config_manager.toString(wrapper)
                            }
                        }
                    }
                }
            case "moving":
                if fieldpos == nil {
                    // // glob.EDITOR.drag_sprite.loc = Point // skip LV Point(x: -100, y: -100) // Point not LV
                } else {
                    if let pt = fieldpos![1].asPoint {
                        // glob.EDITOR.drag_sprite.loc = pt // skip LV Point
                    }
                    let row = fieldpos![0].asPoint?.y ?? 0
                    glob.EDITOR.drag_sprite.locZ = .int(100000 - (1000 * row) + 999)
                    let mpType = movepart?["type"].asString ?? ""
                    if playfield_manager?.checkFit(fieldpos![0], mpType) == true {
                        glob.EDITOR.drag_sprite.blend = 100
                        if mousestate == "press" || (toolmode == "moving" && mousestate == "release") {
                            dragpart?["pos"] = fieldpos![0]
                            if let dp = dragpart {
                                playfield_manager?.placePiece(dp)
                            }
                            if toolmode == "moving" {
                                toolmode = "move"
                            }
                            setdragsprite(.string("reset"))
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
                if mousestate == "press", let fp = fieldpos {
                    movepart = playfield_manager?.erasePiece(fp[0])
                    if movepart == nil {
                        let decal = playfield_manager?.eraseDecal(mouseLoc)
                        if decal == nil {
                            setdragsprite(.string("reset"))
                        } else {
                            bg_edit_item("decal", decal?["member"].asObject()?.asMember)
                            toolmode = "place_decal"
                            glob.EDITOR.drag_sprite.locZ = 200
                        }
                    } else {
                        let mpPos = movepart?["pos"] ?? .void
                        let abovePos: LV
                        if let pt = mpPos.asPoint {
                            abovePos = .point(x: pt.x, y: pt.y - 1)
                        } else {
                            abovePos = .void
                        }
                        moveoffset = (playfield_manager?.getLoc(abovePos) ?? Point(x: 0, y: 0)) - ml
                        setdragsprite(.propList(movepart!))
                        // glob.EDITOR.drag_sprite.loc = playfield_manager // skip LV Point?.getLoc(movepart?["pos"] ?? .void)
                        let row = fp[0].asPoint?.y ?? 0
                        glob.EDITOR.drag_sprite.locZ = .int(100000 - (1000 * row) + 999)
                        toolmode = "moving"
                    }
                }
            case "place_decal":
                // glob.EDITOR.drag_sprite.loc = mouseLoc // skip LV Point
                glob.EDITOR.drag_sprite.blend = 100
                glob.EDITOR.drag_sprite.locZ = 200
                if mousestate == "release", fieldpos != nil {
                    var decalPL = PropList()
                    decalPL["loc"] = .point(x: mouseLoc.x, y: mouseLoc.y)
                    decalPL["member"] = glob.EDITOR.drag_sprite.member
                    playfield_manager?.placeDecal(decalPL)
                    toolmode = "move"
                    setdragsprite(.string("reset"))
                }
            default:
                break
            }
        }
    }

    func doConfigPart(_ part_text: String) {
        let parsed = glob.config_manager.parseParams(part_text)
        guard let newpart = parsed["part"].asPropList else { return }
        var tposX = 0
        var tposY = 0
        if let tposList = newpart["tpos"].asList {
            tposX = tposList[1].asInt ?? 0
            tposY = tposList[2].asInt ?? 0
        }
        newpart["pos"] = .point(x: tposX, y: tposY)
        newpart.deleteOne("tpos")
        playfield_manager?.erasePiece(newpart["pos"])
        playfield_manager?.placePiece(newpart)
    }
}
