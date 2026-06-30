// Translated from Lingo: parent_play manager.ls

public class PlayManager: LingoObject, @unchecked Sendable {
  public override var asPlayManager: PlayManager? { self }
  public var config: LV = .void
  public var playfield_manager: PlayfieldManager? = nil
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

  // Original Lingo body: new
  // ```lingo
  // on new me
  //   activeState = #STANDBY
  //   toolmode = #move
  //   myactors = []
  //   goalList = []
  //   myactorstime = [:]
  //   tracktime = 0
  //   reported_fieldpos = VOID
  //   add(the actorList, me)
  //   return me
  // end
  // ```
  public override init() {
    super.init()
    activeState = "#STANDBY"
    toolmode = "#move"
    myactors = []
    goalList = []
    myactorstime = PropList()
    tracktime = 0
    reported_fieldpos = .void
    Glob.shared["actorList"].asList?.items.append(.object(self))
  }

  // Original Lingo body: destroy
  // ```lingo
  // on destroy me
  //   leave(me)
  //   deleteOne(the actorList, me)
  // end
  // ```
  public func destroy() {
    leave()
    Glob.shared["actorList"].asList?.items.removeAll(where: { $0.asObject() === self })
  }

  // Original Lingo body: leave
  // ```lingo
  // on leave me
  //   me.clearDragBricks()
  //   glob.PLAYER[#partclick_recipient] = VOID
  //   activeState = #STANDBY
  //   setCursor(#none)
  //   myactors = []
  //   if playfield_manager <> VOID then
  //     playfield_manager.leave()
  //   end if
  //   playfield_manager = VOID
  // end
  // ```
  public func leave() {
    clearDragBricks()
    Glob.shared["partclick_recipient"] = .void
    activeState = "#STANDBY"
    setCursor("#none")
    myactors = []
    playfield_manager?.leave()
    playfield_manager = nil
  }

  // Original Lingo body: refresh
  // ```lingo
  // on refresh me
  //   setLevel(me, glob.EDITOR.edit_manager.playfield_manager.current_level)
  // end
  // ```
  public func refresh() {
    // setLevel(Glob.shared.EDITOR.edit_manager.playfield_manager.current_level) -- stub
  }

  // Original Lingo body: actordone
  // ```lingo
  // on actorDone me, a
  //   myactors.deleteOne(a)
  //   myactorstime.deleteOne(a)
  // end
  // ```
  public func actorDone(_ a: AnyObject) {
    myactors.removeAll(where: { $0 === a })
  }

  // Original Lingo body: setlevel
  // ```lingo
  // on setLevel me, conf
  //   toolmode = #move
  //   if ilk(conf) = #string then
  //     config = glob.config_manager.parseParams(conf)
  //   else
  //     config = conf
  //   end if
  //   playfield_manager = new(script("playfield manager"), config.playfield)
  //   playfield_manager.setPlayfield(config)
  //   if not voidp(config[#info]) then
  //     member("level title").text = config.info[#title] && "(" & config.info[#par] & ")"
  //   end if
  //   myactors = []
  //   mytypes = [#MINIFIG: "minifig walk parent", #haz_walker: "hazard walk parent", #HAZ_FLOAT: "hazard float parent", #HAZ_DUMBFLOAT: "hazard dumbfloat parent", #HAZ_CLIMBER: "hazard climb parent", #HAZ_SLICKFAN: "hazard slick fan parent", #HAZ_SLICKFIRE: "hazard slick fire parent", #haz_slickJump: "hazard slick jump parent", #BRICK_SLICKJUMP: "hazard slick jump parent", #HAZ_SLICKPIPE: "hazard slick pipe parent", #HAZ_SLICKSWITCH: "hazard slick switch parent", #HAZ_SLICKSHIELD: "hazard slick shield parent"]
  //   repeat with a = 1 to mytypes.count
  //     active_part_type = mytypes.getPropAt(a)
  //     behavior_script_name = mytypes[a]
  //     repeat with active_part in playfield_manager.getPartsByType([active_part_type])
  //       newactor = new(script(behavior_script_name), active_part)
  //       myactors.add(newactor)
  //       if tracktime then
  //         myactorstime.addProp(newactor, 0)
  //       end if
  //     end repeat
  //   end repeat
  //   goalList = playfield_manager.getPartsByType([#flag])
  //   numGoals = goalList.count
  //   gamestatus = [#damage: 0, #goals: 0, #moves: 0]
  //   me.updateStatus()
  //   activeState = #pause
  // end
  // ```
  public func setLevel(_ conf: LV) {
    toolmode = "#move"
    if conf.isString {
      // config = Glob.shared["config_manager"].asObject()?.parseParams(confStr) -- stub
      config = conf
    } else {
      config = conf
    }
    playfield_manager = PlayfieldManager(config["playfield"] ?? .void)
    playfield_manager?.setPlayfield(config)
    // if config["info"] != nil { member("level title")?.text = ... } -- stub

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

  // Original Lingo body: startlevel
  // ```lingo
  // on startLevel me
  //   glob.PLAYER[#partclick_recipient] = me
  //   activeState = #Run
  // end
  // ```
  public func startLevel() {
    Glob.shared["partclick_recipient"] = .void  // stub: store self reference
    activeState = "#Run"
  }

  // Original Lingo body: pauselevel
  // ```lingo
  // on pauseLevel me, flag
  //   if flag then
  //     glob.PLAYER[#partclick_recipient] = VOID
  //     activeState = #pause
  //   else
  //     glob.PLAYER[#partclick_recipient] = me
  //     activeState = #Run
  //   end if
  // end
  // ```
  public func pauseLevel(_ flag: Bool) {
    if flag {
      Glob.shared["partclick_recipient"] = .void
      activeState = "#pause"
    } else {
      Glob.shared["partclick_recipient"] = .void  // stub: store self reference
      activeState = "#Run"
    }
  }

  // Original Lingo body: setdragsprite
  // ```lingo
  // on setdragsprite me, opt
  //   if glob.EDITOR[#drag_sprite] = VOID then
  //     return
  //   end if
  //   glob.EDITOR.drag_sprite.puppet = 1
  //   if opt = #reset then
  //     glob.EDITOR.drag_sprite.loc = point(-100, -100)
  //     glob.EDITOR.drag_sprite.blend = 100
  //     return
  //   else
  //     if ilk(opt) = #propList then
  //       myType = opt.type
  //       myColor = opt.color
  //       myMember = opt.member
  //     else
  //       return
  //     end if
  //   end if
  //   dragmember = myMember
  //   glob.EDITOR.drag_sprite.member = myMember
  //   glob.EDITOR.drag_sprite.width = glob.EDITOR.drag_sprite.member.width * playfield_manager.pf_scale
  //   glob.EDITOR.drag_sprite.height = glob.EDITOR.drag_sprite.member.height * playfield_manager.pf_scale
  // end
  // ```
  public func setdragsprite(_ opt: PropList?) {
    guard let opt = opt else { return }
    dragmember = opt["member"]
  }

  // Original Lingo body: instantwin
  // ```lingo
  // on instantWin me
  //   if glob[#authorMode] <> 1 then
  //     return
  //   end if
  // end
  // ```
  public func instantWin() {
    guard Glob.shared["authorMode"].asInt == 1 else { return }
  }

  // Original Lingo body: addstatus
  // ```lingo
  // on addStatus me, p, d
  //   case p of
  //     #damage:
  //       SndSFX("die")
  //       activeState = #pause
  //       me.clearDragBricks()
  //       setCursor(#none)
  //       glob.PLAYER.game_manager.endLevel(#LOSE)
  //       setCursor(#none)
  //     #goals:
  //       numGoals = numGoals - 1
  //       if numGoals = 0 then
  //         activeState = #pause
  //         me.clearDragBricks()
  //         setCursor(#none)
  //         glob.PLAYER.game_manager.endLevel(#WIN)
  //         setCursor(#none)
  //       end if
  //   end case
  //   gamestatus[p] = gamestatus[p] + d
  //   me.updateStatus()
  // end
  // ```
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

  // Original Lingo body: updatestatus
  // ```lingo
  // on updateStatus me
  //   t = EMPTY
  //   repeat with i = 1 to gamestatus.count
  //     t = t & gamestatus.getPropAt(i) & ":" && gamestatus[i] & RETURN
  //   end repeat
  //   member("play status field").text = t
  //   member("play move counter field").text = string(gamestatus.moves)
  // end
  // ```
  public func updateStatus() {
    var t = ""
    for prop in gamestatus.props {
      t += "\(prop.key): \(prop.value)\n"
    }
    // member("play status field")?.text = t -- stub
    // member("play move counter field")?.text = String(gamestatus["#moves"].asInt ?? 0) -- stub
    debugLog(t)
  }

  // Original Lingo body: doswitch
  // ```lingo
  // on doSwitch me, args
  //   repeat with part in playfield_manager.getPartsByLabel(args.label)
  //     part.behavior.notify([#switch: args.state])
  //   end repeat
  // end
  // ```
  public func doSwitch(_ args: PropList) {
    // repeat with part in playfield_manager.getPartsByLabel(args["label"]) { part.behavior.notify(["switch": args["state"]]) } -- stub
  }

  // Original Lingo body: cleardragbricks
  // ```lingo
  // on clearDragBricks me
  //   if ilk(movePieceGroup) = #list then
  //     repeat with ss in movePieceGroup
  //       repeat with s in ss.sprite
  //         s.loc = point(-200, -200)
  //       end repeat
  //     end repeat
  //   end if
  // end
  // ```
  public func clearDragBricks() {
    // movePieceGroup sprite manipulation -- stub
  }

  // Original Lingo body: partclick
  // ```lingo
  // on partclick me, part, evt
  //   case evt of
  //     #mouseEnter:
  //       reported_fieldpos = [part.pos, part.sprite[1].loc]
  //     #mouseLeave:
  //       reported_fieldpos = VOID
  //   end case
  // end
  // ```
  public func partclick(_ part: LV, _ evt: String) {
    switch evt {
    case "#mouseEnter":
      reported_fieldpos = .list(LingoList([part.asPropList?["pos"] ?? .void]))
      break
    case "#mouseLeave":
      reported_fieldpos = .void
    default:
      break
    }
  }

  // Original Lingo body: stepframe
  // ```lingo
  // on stepFrame me
  //   if not (activeState = #Run) then
  //     return
  //   end if
  //   if glob.EDITOR[#drag_sprite] = VOID then
  //     return
  //   end if
  //   if playfield_manager = VOID then
  //     return
  //   end if
  //   repeat with a in myactors.duplicate()
  //     ms = the milliSeconds
  //     a.stepFrame()
  //     if tracktime then
  //       myactorstime[a] = myactorstime[a] + the milliSeconds - ms
  //     end if
  //   end repeat
  //   if toolmode = VOID then
  //     toolmode = #move
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
  //   if toolmode = #dragging then
  //     ml = ml + moveoffset
  //   end if
  //   fieldpos = playfield_manager.getPos(ml)
  //   case toolmode of
  //     #dragging:
  //       if fieldpos = VOID then
  //         repeat with mp in movePieceGroup
  //           repeat with s in mp.sprite
  //             s.blend = 0
  //           end repeat
  //         end repeat
  //       else
  //         posOffSet = fieldpos[1] - movePieceGroup[1].pos
  //         locOffset = pressLoc - movePieceGroup[1].sprite[1].loc
  //         everythingPlaceable = 1
  //         fitDir = VOID
  //         repeat with mp in movePieceGroup
  //           check = playfield_manager.checkPlaceable(mp.pos + posOffSet, mp.type)
  //           if check = #nofit then
  //             everythingPlaceable = 0
  //             exit repeat
  //             next repeat
  //           end if
  //           if check = #above then
  //             if fitDir = #below then
  //               everythingPlaceable = 0
  //               exit repeat
  //             else
  //               fitDir = #above
  //             end if
  //             next repeat
  //           end if
  //           if check = #below then
  //             if fitDir = #above then
  //               everythingPlaceable = 0
  //               exit repeat
  //             else
  //               fitDir = #below
  //             end if
  //             next repeat
  //           end if
  //         end repeat
  //         if voidp(fitDir) then
  //           everythingPlaceable = 0
  //         end if
  //         repeat with mp in movePieceGroup
  //           repeat with si = 1 to mp.sprite.count
  //             s = mp.sprite[si]
  //             s.loc = playfield_manager.getLoc(mp.pos + posOffSet)
  //             s.locZ = playfield_manager.posToLocZ(mp.pos + posOffSet - point(0, si - 1))
  //             if everythingPlaceable then
  //               s.blend = 75
  //               next repeat
  //             end if
  //             s.blend = 25
  //           end repeat
  //         end repeat
  //         if everythingPlaceable and ((mousestate = #press) or (mousestate = #release)) then
  //           repeat with mp in movePieceGroup
  //             mp.pos = mp.pos + posOffSet
  //             playfield_manager.placePiece(mp)
  //           end repeat
  //           toolmode = #move
  //           SndSFX("blockdrop")
  //           movePieceGroup = []
  //         end if
  //       end if
  //     #move:
  //       if not voidp(reported_fieldpos) then
  //         fieldpos = reported_fieldpos
  //       end if
  //       if voidp(fieldpos) then
  //         setCursor(#none)
  //       else
  //         temp = [:]
  //         temp[#down] = playfield_manager.findPieceGroup(fieldpos[1], #down)
  //         temp[#UP] = playfield_manager.findPieceGroup(fieldpos[1], #UP)
  //         if (temp[#down] = []) and (temp[#UP] = []) then
  //           setCursor(#none)
  //         else
  //           if temp[#down] = [] then
  //             setCursor(#grab_up)
  //           else
  //             if temp[#UP] = [] then
  //               setCursor(#grab_down)
  //             else
  //               setCursor(#grab_both)
  //             end if
  //           end if
  //           if mousestate = #press then
  //             pressLoc = ml
  //             pressPos = fieldpos[1]
  //             toolmode = #pressing
  //             SndSFX("blockclick")
  //             me.doPressing(ml)
  //           end if
  //         end if
  //       end if
  //     #pressing:
  //       me.doPressing(ml)
  //   end case
  //   if keyPressed(" ") and (activeState = #Run) then
  //     me.instantWin()
  //   end if
  // end
  // ```
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

    let ml = Glob.shared["mouseLoc"].asPoint ?? Point()
    var mlWithOffset = ml
    if toolmode == "#dragging" {
      mlWithOffset = ml + moveoffset
    }
    let fieldposArr = playfield_manager?.getPos(mlWithOffset)
    var fieldpos: [LV]? = fieldposArr

    switch toolmode {
    case "#dragging":
      if fieldpos == nil {
        // sprite blend = 0
      } else {
        let everythingPlaceable = 1  // Simplified stub for dragging
        // place pieces...
        if everythingPlaceable == 1 && (mousestate == "#press" || mousestate == "#release") {
          if let group = movePieceGroup.asList?.items {
            for mpLV in group {
              let mp = mpLV.asPropList
              playfield_manager?.placePiece(mp ?? PropList())
            }
          }
          toolmode = "#move"
          SndSFX("blockdrop")
          movePieceGroup = .void
        }
      }
    case "#move":
      if !reported_fieldpos.isVoid {
        fieldpos = reported_fieldpos.asList?.items
      }
      if fieldpos == nil || fieldpos!.isEmpty {
        setCursor("#none")
      } else {
        var temp = PropList()
        let pos = fieldpos![0].asPoint ?? Point()
        let posArr = [pos.x, pos.y]
        temp["#down"] = .list(
          LingoList(
            playfield_manager?.findPieceGroup(posArr, dir: "#down").map { .propList($0) } ?? []))
        temp["#UP"] = .list(
          LingoList(
            playfield_manager?.findPieceGroup(posArr, dir: "#UP").map { .propList($0) } ?? []))

        let downEmpty = temp["#down"].asList?.isEmpty ?? true
        let upEmpty = temp["#UP"].asList?.isEmpty ?? true

        if downEmpty && upEmpty {
          setCursor("#none")
        } else if downEmpty {
          setCursor("#grab_up")
        } else if upEmpty {
          setCursor("#grab_down")
        } else {
          setCursor("#grab_both")
        }

        if mousestate == "#press" {
          pressLoc = ml
          pressPos = fieldpos![0]
          toolmode = "#pressing"
          SndSFX("blockclick")
          doPressing(ml)
        }
      }
    case "#pressing":
      doPressing(ml)
    default:
      break
    }

    if keyPressed(" ") && activeState == "#Run" {
      instantWin()
    }
  }

  // Original Lingo body: dopressing
  // ```lingo
  // on doPressing me, ml
  //   temp = [:]
  //   temp[#down] = playfield_manager.findPieceGroup(pressPos, #down)
  //   temp[#UP] = playfield_manager.findPieceGroup(pressPos, #UP)
  //   dragDir = 0
  //   pressOffSet = ml - pressLoc
  //   if (pressOffSet[2] > 3) or (temp[#UP] = []) then
  //     dragDir = #down
  //   end if
  //   if (pressOffSet[2] < -3) or (temp[#down] = []) then
  //     dragDir = #UP
  //   end if
  //   if dragDir = 0 then
  //     if mousestate = #release then
  //       toolmode = #move
  //     end if
  //   end if
  //   if not (dragDir = 0) then
  //     movePieceGroup = temp[dragDir]
  //     if movePieceGroup = [] then
  //       if abs(pressOffSet[2]) > 20 then
  //         toolmode = #move
  //       end if
  //     else
  //       playfield_manager.erasePieceGroup(movePieceGroup, 1)
  //       moveoffset = playfield_manager.getLoc(movePieceGroup[1].pos + point(0, -1)) - pressLoc
  //       repeat with mp in movePieceGroup
  //         repeat with s in mp.sprite
  //           s.blend = 75
  //         end repeat
  //       end repeat
  //       toolmode = #dragging
  //       setCursor(#grabber)
  //       SndSFX("blockpickup")
  //       me.addStatus(#moves, 1)
  //     end if
  //   end if
  // end
  // ```
  public func doPressing(_ ml: Point) {
    var temp = PropList()
    let posArr = [pressPos.asPoint?.x ?? 0, pressPos.asPoint?.y ?? 0]
    temp["#down"] = .list(
      LingoList(playfield_manager?.findPieceGroup(posArr, dir: "#down").map { .propList($0) } ?? [])
    )
    temp["#UP"] = .list(
      LingoList(playfield_manager?.findPieceGroup(posArr, dir: "#UP").map { .propList($0) } ?? []))
    var dragDir: String? = nil
    let pressOffSet = Point(x: ml.x - pressLoc.x, y: ml.y - pressLoc.y)

    let upEmpty = temp["#UP"].asList?.isEmpty ?? true
    let downEmpty = temp["#down"].asList?.isEmpty ?? true

    if pressOffSet.y > 3 || upEmpty {
      dragDir = "#down"
    }
    if pressOffSet.y < -3 || downEmpty {
      dragDir = "#UP"
    }
    if dragDir == nil {
      if mousestate == "#release" {
        toolmode = "#move"
      }
    }
    if let dDir = dragDir {
      movePieceGroup = temp[dDir]
      if movePieceGroup.asList?.isEmpty ?? true {
        if abs(pressOffSet.y) > 20 {
          toolmode = "#move"
        }
      } else {
        // playfield_manager.erasePieceGroup(movePieceGroup, 1) -- stub
        toolmode = "#dragging"
        setCursor("#grabber")
        SndSFX("blockpickup")
        addStatus("#moves", 1)
      }
    }
  }
}
