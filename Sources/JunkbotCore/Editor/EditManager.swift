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

  // Original Lingo body: new
  // ```lingo
  // on new me
  //   me.setConfig()
  //   playfield_manager = new(script("playfield manager"), config.playfield)
  //   add(the actorList, me)
  //   toolmode = #none
  //   toolparam = VOID
  //   toolcolor = "GRAY"
  //   return me
  // end
  // ```
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

  // Original Lingo body: destroy
  // ```lingo
  // on destroy me
  //   leave(me)
  //   deleteOne(the actorList, me)
  // end
  // ```
  func destroy() {
    leave()
    actorList.removeAll { $0 === self }
  }

  // Original Lingo body: leave
  // ```lingo
  // on leave me
  //   playfield_manager.setInfo([#title: field("catalog title"), #par: field("editor par field"), #hint: field("editor hint field")])
  //   currentLevel = playfield_manager.toString()
  //   glob.PLAYER.game_manager.setGame([currentLevel])
  //   setCursor(#none)
  //   playfield_manager.leave()
  // end
  // ```
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

  // Original Lingo body: refresh
  // ```lingo
  // on refresh me
  //   playfield_manager.refresh()
  //   info = playfield_manager.getInfo()
  //   if not voidp(info) then
  //     member("catalog title").text = string(info[#title])
  //     member("catalog par").text = string(info[#par])
  //     member("catalog hint").text = string(info[#hint])
  //   else
  //     member("catalog title").text = EMPTY
  //     member("catalog par").text = EMPTY
  //     member("catalog hint").text = EMPTY
  //   end if
  //   settoolmode(me, toolmode, toolparam, toolstate, toolframe)
  // end
  // ```
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

  // Original Lingo body: setconfig
  // ```lingo
  // on setConfig me
  //   configtext = member("config field").text
  //   config = glob[#config_manager].parseParams(configtext)
  //   if playfield_manager <> VOID then
  //     playfield_manager.setConfig(config.playfield)
  //   end if
  // end
  // ```
  func setConfig() {
    let configtext = member("config field")?.text
    config = glob.config_manager.parseParams(configtext ?? "")
    if playfield_manager != nil {
      playfield_manager?.setConfig(config["playfield"])
    }
  }

  // Original Lingo body: settoolmode
  // ```lingo
  // on settoolmode me, m, p, s, f
  //   toolmode = m
  //   toolparam = p
  //   toolstate = s
  //   toolframe = f
  //   case toolmode of
  //     #move:
  //       setCursor(#grab)
  //       me.setdragsprite(#reset)
  //     #erase:
  //       setCursor(#eraser)
  //       me.setdragsprite(#reset)
  //     #place:
  //       setCursor(#none)
  //       me.setdragsprite([#type: toolparam, #color: toolcolor, #state: toolstate, #frame: toolframe])
  //     otherwise:
  //       setCursor(#none)
  //   end case
  // end
  // ```
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

  // Original Lingo body: settoolcolor
  // ```lingo
  // on settoolcolor me, c
  //   toolcolor = c
  //   if (glob.EDITOR[#drag_sprite] <> VOID) and (toolparam <> VOID) then
  //     me.setdragsprite([#color: toolcolor])
  //   end if
  // end
  // ```
  func settoolcolor(_ c: String) {
    toolcolor = c
    if !glob.EDITOR["drag_sprite"].isVoid, toolparam != nil {
      var optDict = PropList()
      optDict["color"] = .string(toolcolor)
      setdragsprite(.propList(optDict))
    }
  }

  // Original Lingo body: bg_edit_item
  // ```lingo
  // on bg_edit_item me, kind, mem
  //   case kind of
  //     #backdrop:
  //       playfield_manager.setBackdrop(mem.name)
  //     #decal:
  //       toolmode = #place_decal
  //       dragmember = mem
  //       glob.EDITOR.drag_sprite.member = dragmember
  //       glob.EDITOR.drag_sprite.rect = dragmember.rect
  //       glob.EDITOR.drag_sprite.ink = 36
  //       glob.EDITOR.drag_sprite.locZ = 200
  //       setCursor(#none)
  //   end case
  // end
  // ```
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

  // Original Lingo body: setdragsprite
  // ```lingo
  // on setdragsprite me, opt
  //   if glob.EDITOR[#drag_sprite] = VOID then
  //     return
  //   end if
  //   glob.EDITOR.drag_sprite.puppet = 1
  //   glob.EDITOR.drag_sprite.ink = 36
  //   if opt = #reset then
  //     glob.EDITOR.drag_sprite.loc = point(-100, -100)
  //     glob.EDITOR.drag_sprite.blend = 100
  //     dragpart = VOID
  //     return
  //   else
  //     if ilk(opt) = #propList then
  //       if not voidp(opt[#type]) then
  //         dragpart = opt
  //       else
  //         if dragpart <> VOID then
  //           dragpart[#color] = opt.color
  //         end if
  //       end if
  //     else
  //       return
  //     end if
  //   end if
  //   if dragpart <> VOID then
  //     dragmembername = glob.legoparts_manager.getPieceMemberName(dragpart, #single)
  //     dragmember = member(dragmembername)
  //     glob.EDITOR.drag_sprite.member = dragmember
  //     glob.EDITOR.drag_sprite.width = glob.EDITOR.drag_sprite.member.width * playfield_manager.pf_scale
  //     glob.EDITOR.drag_sprite.height = glob.EDITOR.drag_sprite.member.height * playfield_manager.pf_scale
  //   end if
  // end
  // ```
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
      let dragmembername =
        glob.legoparts_manager.getPieceMemberName(part: dp, single: "single").asString ?? ""
      let dragmember = member(dragmembername)
      glob.EDITOR.drag_sprite.member = dragmember.map { LV.object($0) } ?? .void
      glob.EDITOR.drag_sprite.width = .int(dragmember?.width ?? 0)
      glob.EDITOR.drag_sprite.height = .int(dragmember?.height ?? 0)
    }
  }

  // Original Lingo body: stepframe
  // ```lingo
  // on stepFrame me
  //   if the frame <> marker("edit") then
  //     return
  //   end if
  //   if the mouseDown then
  //     if mousestate = #UP then
  //       mousestate = #press
  //     else
  //       mousestate = #down
  //     end if
  //   else
  //     if mousestate = #down then
  //       mousestate = #release
  //     else
  //       mousestate = #UP
  //     end if
  //   end if
  //   ml = the mouseLoc
  //   if toolmode = #moving then
  //     ml = ml + moveoffset
  //   end if
  //   fieldpos = playfield_manager.getPos(ml)
  //   if glob.EDITOR[#drag_sprite] <> VOID then
  //     case toolmode of
  //       #place:
  //         if voidp(fieldpos) then
  //           glob.EDITOR.drag_sprite.loc = point(-100, -100)
  //         else
  //           glob.EDITOR.drag_sprite.loc = fieldpos[2]
  //           glob.EDITOR.drag_sprite.locZ = 100000 - (1000 * fieldpos[1][2]) + 999
  //           if playfield_manager.checkFit(fieldpos[1], toolparam) then
  //             glob.EDITOR.drag_sprite.blend = 100
  //             if mousestate = #press then
  //               dragpart[#pos] = fieldpos[1]
  //               tpart = dragpart.duplicate()
  //               if ((tpart.type = #HAZ_SLICKSWITCH) or (tpart.type = #HAZ_SLICKFIRE) or (tpart.type = #HAZ_SLICKFAN)) and voidp(tpart[#label]) then
  //                 tpart[#label] = "switch1"
  //               end if
  //               playfield_manager.placePiece(tpart)
  //             end if
  //           else
  //             glob.EDITOR.drag_sprite.blend = 30
  //           end if
  //         end if
  //       #config:
  //         if mousestate = #press then
  //           if not voidp(fieldpos) then
  //             tpart = playfield_manager.getPart(fieldpos[1])
  //             if voidp(tpart) then
  //               put EMPTY into field "part inspector field"
  //             else
  //               tpart = tpart.duplicate()
  //               tpart.deleteProp(#sprite)
  //               tpos = tpart[#pos]
  //               tpart.deleteProp(#pos)
  //               tpart[#tpos] = [tpos[1], tpos[2]]
  //               case tpart.type of
  //                 #HAZ_SLICKSWITCH, #HAZ_SLICKFIRE, #HAZ_SLICKFAN:
  //                   if voidp(tpart[#label]) then
  //                     tpart[#label] = "switch1"
  //                   end if
  //               end case
  //               put glob.config_manager.toString([#part: tpart]) into field "part inspector field"
  //             end if
  //           end if
  //         end if
  //       #moving:
  //         if fieldpos = VOID then
  //           glob.EDITOR.drag_sprite.loc = point(-100, -100)
  //         else
  //           glob.EDITOR.drag_sprite.loc = fieldpos[2]
  //           glob.EDITOR.drag_sprite.locZ = 100000 - (1000 * fieldpos[1][2]) + 999
  //           if playfield_manager.checkFit(fieldpos[1], movepart.type) then
  //             glob.EDITOR.drag_sprite.blend = 100
  //             if (mousestate = #press) or ((toolmode = #moving) and (mousestate = #release)) then
  //               dragpart[#pos] = fieldpos[1]
  //               tpart = dragpart.duplicate()
  //               playfield_manager.placePiece(tpart)
  //               if toolmode = #moving then
  //                 toolmode = #move
  //               end if
  //               setdragsprite(#reset)
  //             end if
  //           else
  //             glob.EDITOR.drag_sprite.blend = 30
  //           end if
  //         end if
  //       #erase:
  //         if not voidp(fieldpos) and (mousestate = #release) then
  //           tmppart = playfield_manager.erasePiece(fieldpos[1])
  //           if voidp(tmppart) then
  //             playfield_manager.eraseDecal(the mouseLoc)
  //           end if
  //         end if
  //       #move:
  //         if (mousestate = #press) and not voidp(fieldpos) then
  //           movepart = playfield_manager.erasePiece(fieldpos[1])
  //           if voidp(movepart) then
  //             decal = playfield_manager.eraseDecal(the mouseLoc)
  //             if voidp(decal) then
  //               me.setdragsprite(#reset)
  //             else
  //               me.bg_edit_item(#decal, decal.member)
  //               toolmode = #place_decal
  //               glob.EDITOR.drag_sprite.locZ = 200
  //             end if
  //           else
  //             moveoffset = playfield_manager.getLoc(movepart.pos + point(0, -1)) - ml
  //             me.setdragsprite(movepart)
  //             glob.EDITOR.drag_sprite.loc = playfield_manager.getLoc(movepart.pos)
  //             glob.EDITOR.drag_sprite.locZ = 100000 - (1000 * fieldpos[1][2]) + 999
  //             toolmode = #moving
  //           end if
  //         end if
  //       #place_decal:
  //         glob.EDITOR.drag_sprite.loc = the mouseLoc
  //         glob.EDITOR.drag_sprite.blend = 100
  //         glob.EDITOR.drag_sprite.locZ = 200
  //         if (mousestate = #release) and not voidp(fieldpos) then
  //           playfield_manager.placeDecal([#loc: glob.EDITOR.drag_sprite.loc, #member: glob.EDITOR.drag_sprite.member])
  //           toolmode = #move
  //           me.setdragsprite(#reset)
  //         end if
  //     end case
  //   end if
  // end
  // ```
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
                if partType == "HAZ_SLICKSWITCH" || partType == "HAZ_SLICKFIRE"
                  || partType == "HAZ_SLICKFAN",
                  dp["label"].isVoid
                {
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

  // Original Lingo body: doconfigpart
  // ```lingo
  // on doConfigPart me, part_text
  //   newpart = glob.config_manager.parseParams(part_text)[#part]
  //   newpart[#pos] = point(newpart.tpos[1], newpart.tpos[2])
  //   newpart.deleteProp(#tpos)
  //   playfield_manager.erasePiece(newpart.pos)
  //   playfield_manager.placePiece(newpart)
  // end
  // ```
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
