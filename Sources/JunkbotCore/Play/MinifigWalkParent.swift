// Translated from Lingo: parent_minifig walk parent.ls

public class MinifigWalkParent: LingoObject, @unchecked Sendable {
    public var playfield_manager: LV = .void
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var speed: Int = 4
    public var step_up: Int = 1
    public var step_down: Int = 1
    public var fall_down: Int = 0
    public var jump_over: Int = 1
    public var last_step: Int = 0
    public var painmode: Int = 0
    public var painTicks: Int? = nil
    public var frameMax: Int = 10
    public var frameCounter: Int = 1
    public var fanMode: Int = 0
    public var mode: String = "#WALK"
    public var SHIELD: Int = 0
    public var shieldticks: Int? = nil
    public var cause_of_death: String? = nil
    public var jump_trajectory_r: [PropList] = []
    public var jump_index: Int = 1
    public var dir: Int = 1

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   part[#behavior] = me
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   painmode = 0
    //   fanMode = 0
    //   mode = #WALK
    //   myWidth = 2
    //   SHIELD = 0
    //   shieldticks = VOID
    //   if part.state = #WALK_R then
    //     dir = 1
    //   else
    //     if part.state = #walk_l then
    //       dir = -1
    //     else
    //       dir = (random(2) * 2) - 3
    //     end if
    //   end if
    //   speed = 4
    //   step_up = 1
    //   step_down = 1
    //   fall_down = 0
    //   jump_over = 1
    //   last_step = the ticks
    //   frameMax = 10
    //   frameCounter = 1
    //   jump_trajectory_r = [[#v: [0, -1], #o: point(4, 0)], [#v: [1, -1], #o: point(-2, 0)], [#v: [1, -1], #o: point(0, 0)], [#v: [1, 0], #o: point(0, 0)], [#v: [1, 1], #o: point(2, 0)], [#v: [1, 1], #o: point(-4, 0)], [#v: [0, 1], #o: point(0, 0)]]
    //   return me
    // end
    // ```
    public init(_ p: PropList) {
        super.init()
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        painmode = 0
        fanMode = 0
        mode = "#WALK"
        myWidth = 2
        SHIELD = 0
        shieldticks = nil

        let state = p["state"].asString ?? ""
        if state == "#WALK_R" {
            dir = 1
        } else if state == "#walk_l" {
            dir = -1
        } else {
            dir = (lingoRandom(2) * 2) - 3
        }

        speed = 4
        step_up = 1
        step_down = 1
        fall_down = 0
        jump_over = 1
        last_step = currentTicks
        frameMax = 10
        frameCounter = 1

        var t0 = PropList()
        t0["v"] = .list({ let l = LingoList(); l.add(.int(0)); l.add(.int(-1)); return l }())
        t0["o"] = .point(x: 4, y: 0)
        var t1 = PropList()
        t1["v"] = .list({ let l = LingoList(); l.add(.int(1)); l.add(.int(-1)); return l }())
        t1["o"] = .point(x: -2, y: 0)
        var t2 = PropList()
        t2["v"] = .list({ let l = LingoList(); l.add(.int(1)); l.add(.int(-1)); return l }())
        t2["o"] = .point(x: 0, y: 0)
        var t3 = PropList()
        t3["v"] = .list({ let l = LingoList(); l.add(.int(1)); l.add(.int(0)); return l }())
        t3["o"] = .point(x: 0, y: 0)
        var t4 = PropList()
        t4["v"] = .list({ let l = LingoList(); l.add(.int(1)); l.add(.int(1)); return l }())
        t4["o"] = .point(x: 2, y: 0)
        var t5 = PropList()
        t5["v"] = .list({ let l = LingoList(); l.add(.int(1)); l.add(.int(1)); return l }())
        t5["o"] = .point(x: -4, y: 0)
        var t6 = PropList()
        t6["v"] = .list({ let l = LingoList(); l.add(.int(0)); l.add(.int(1)); return l }())
        t6["o"] = .point(x: 0, y: 0)
        jump_trajectory_r = [t0, t1, t2, t3, t4, t5, t6]
    }

    // Original Lingo body: done
    // ```lingo
    // on done me
    //   play_manager.actorDone(me)
    // end
    // ```
    public func done() {
        if let pm = play_manager { pm.actorDone(self) }
    }

    // Original Lingo body: notify
    // ```lingo
    // on notify me, notes
    //   if notes[#destroyed] = 1 then
    //     me.done()
    //   else
    //     if not voidp(notes[#pos]) then
    //       part.pos = notes[#pos]
    //     else
    //       if not voidp(notes[#damage]) then
    //         if mode <> #DEAD then
    //           if SHIELD = 1 then
    //             if voidp(shieldticks) then
    //               shieldticks = the ticks + 120
    //             end if
    //           else
    //             frameCounter = 1
    //             part.frame = 1
    //             mode = #DEAD
    //             cause_of_death = notes[#damage]
    //             case cause_of_death of
    //               #drip:
    //                 part.state = #DEAD_DRIP
    //               otherwise:
    //                 part.state = #DEAD_GENERIC
    //             end case
    //           end if
    //         end if
    //       else
    //         if not voidp(notes[#FAN]) and voidp(cause_of_death) then
    //           fanMode = 1
    //         else
    //           if not voidp(notes[#jump]) then
    //             if mode <> #jump then
    //               mode = #jump
    //               jump_index = 1
    //             end if
    //           else
    //             if not voidp(notes[#SHIELD]) then
    //               SndSFX("h_powerup1")
    //               SndSFX("shieldon2")
    //               mode = #SHIELDON
    //               part.frame = 1
    //               frameCounter = 1
    //               if dir < 0 then
    //                 part.state = #SHIELDON_L
    //               else
    //                 part.state = #SHIELDON_R
    //               end if
    //               SHIELD = 1
    //               shieldticks = VOID
    //             end if
    //           end if
    //         end if
    //       end if
    //     end if
    //   end if
    // end
    // ```
    public func notify(_ notes: PropList) {
        if let destroyed = notes["destroyed"].asInt, destroyed == 1 {
            done()
        } else if !notes["pos"].isVoid {
            part["pos"] = notes["pos"]
        } else if let damage = notes["damage"].asString {
            if mode != "#DEAD" {
                if SHIELD == 1 {
                    if shieldticks == nil {
                        shieldticks = currentTicks + 120
                    }
                } else {
                    frameCounter = 1
                    part["frame"] = .int(1)
                    mode = "#DEAD"
                    cause_of_death = damage
                    switch damage {
                    case "#drip":
                        part["state"] = .string("#DEAD_DRIP")
                    default:
                        part["state"] = .string("#DEAD_GENERIC")
                    }
                }
            }
        } else if !notes["FAN"].isVoid && cause_of_death == nil {
            fanMode = 1
        } else if !notes["jump"].isVoid {
            if mode != "#jump" {
                mode = "#jump"
                jump_index = 1
            }
        } else if !notes["SHIELD"].isVoid {
            SndSFX("h_powerup1")
            SndSFX("shieldon2")
            mode = "#SHIELDON"
            part["frame"] = .int(1)
            frameCounter = 1
            if dir < 0 {
                part["state"] = .string("#SHIELDON_L")
            } else {
                part["state"] = .string("#SHIELDON_R")
            }
            SHIELD = 1
            shieldticks = nil
        }
    }

    // Original Lingo body: step
    // ```lingo
    // on step me
    //   pos = part.pos + point(dir, 0)
    //   Ok = 0
    //   fg = playfield_manager.checkFitOrGoal(pos, part.type)
    //   if fg <> 0 then
    //     if playfield_manager.checkFloor(pos, 2) then
    //       Ok = 1
    //       me.doWalkState()
    //       part.pos = pos
    //     end if
    //   end if
    //   if not Ok then
    //     repeat with s = 1 to step_down
    //       pos = part.pos + point(dir, 0) + point(0, s)
    //       fg = playfield_manager.checkFitOrGoal(pos, part.type)
    //       if fg <> 0 then
    //         if playfield_manager.checkFloor(pos, 2) then
    //           Ok = 1
    //           me.doWalkState()
    //           part.pos = pos
    //           exit repeat
    //         end if
    //       end if
    //     end repeat
    //   end if
    //   if not Ok then
    //     repeat with s = 1 to step_up
    //       pos = part.pos + point(dir, 0) + point(0, -s)
    //       fg = playfield_manager.checkFitOrGoal(pos, part.type)
    //       if fg <> 0 then
    //         if playfield_manager.checkFloor(pos, 2) then
    //           Ok = 1
    //           me.doWalkState()
    //           part.pos = pos
    //           exit repeat
    //         end if
    //       end if
    //     end repeat
    //   end if
    //   if not Ok then
    //     dir = -dir
    //     me.doWalkState()
    //     SndSFX("turn1")
    //   end if
    //   if ilk(fg) = #propList then
    //     SndSFX("garbage1")
    //     SndSFX("eat1")
    //     SndSFX("h_misc_1")
    //     mode = #EAT
    //     part.frame = 1
    //     if dir < 0 then
    //       if SHIELD = 1 then
    //         part.state = #SHIELDEAT_L
    //       else
    //         part.state = #EAT_L
    //       end if
    //     else
    //       if SHIELD = 1 then
    //         part.state = #SHIELDEAT_R
    //       else
    //         part.state = #EAT_R
    //       end if
    //     end if
    //     playfield_manager.erasePiece(fg.pos)
    //   end if
    // end
    // ```
    public func step() {
        // pos = part.pos + point(dir, 0) -- stub
        var ok = false
        // fg = playfield_manager.checkFitOrGoal(pos, part.type) -- stub
        let fg: LV = .void
        _ = fg
        // if fg != 0 { if playfield_manager.checkFloor(pos, 2) { ok = true; doWalkState(); part.pos = pos } }
        if !ok {
            for s in 1...step_down {
                _ = s
                // fg = playfield_manager.checkFitOrGoal(pos, part.type) -- stub
                // if fg != 0 && playfield_manager.checkFloor(pos, 2) { ok = true; doWalkState(); part.pos = pos; break }
            }
        }
        if !ok {
            for s in 1...step_up {
                _ = s
                // fg = playfield_manager.checkFitOrGoal(pos, part.type) -- stub
                // if fg != 0 && playfield_manager.checkFloor(pos, 2) { ok = true; doWalkState(); part.pos = pos; break }
            }
        }
        if !ok {
            dir = -dir
            doWalkState()
            SndSFX("turn1")
        }
        // if fg.isPropList { eat animation, erase piece } -- stub
    }

    // Original Lingo body: dowalkstate
    // ```lingo
    // on doWalkState me
    //   if dir < 0 then
    //     if SHIELD = 1 then
    //       if not voidp(shieldticks) then
    //         if (integer((shieldticks - the ticks) / 6) mod 2) = 1 then
    //           part.state = #walk_l
    //         else
    //           part.state = #SHIELDWALK_L
    //         end if
    //       else
    //         part.state = #SHIELDWALK_L
    //       end if
    //     else
    //       part.state = #walk_l
    //     end if
    //   else
    //     if SHIELD = 1 then
    //       if not voidp(shieldticks) then
    //         if (integer((shieldticks - the ticks) / 10) mod 2) = 1 then
    //           part.state = #WALK_R
    //         else
    //           part.state = #SHIELDWALK_R
    //         end if
    //       else
    //         part.state = #SHIELDWALK_R
    //       end if
    //     else
    //       part.state = #WALK_R
    //     end if
    //   end if
    // end
    // ```
    public func doWalkState() {
        let ticks = currentTicks
        if dir < 0 {
            if SHIELD == 1 {
                if let st = shieldticks {
                    if ((st - ticks) / 6) % 2 == 1 {
                        part["state"] = .string("#walk_l")
                    } else {
                        part["state"] = .string("#SHIELDWALK_L")
                    }
                } else {
                    part["state"] = .string("#SHIELDWALK_L")
                }
            } else {
                part["state"] = .string("#walk_l")
            }
        } else {
            if SHIELD == 1 {
                if let st = shieldticks {
                    if ((st - ticks) / 10) % 2 == 1 {
                        part["state"] = .string("#WALK_R")
                    } else {
                        part["state"] = .string("#SHIELDWALK_R")
                    }
                } else {
                    part["state"] = .string("#SHIELDWALK_R")
                }
            } else {
                part["state"] = .string("#WALK_R")
            }
        }
    }

    // Original Lingo body: stepanim
    // ```lingo
    // on stepAnim me
    //   part.frame = frameCounter
    //   frameCounter = frameCounter + 1
    //   if frameCounter > frameMax then
    //     frameCounter = 1
    //   end if
    // end
    // ```
    public func stepAnim() {
        part["frame"] = .int(frameCounter)
        frameCounter += 1
        if frameCounter > frameMax {
            frameCounter = 1
        }
    }

    // Original Lingo body: fananim
    // ```lingo
    // on fanAnim me
    //   pos = part.pos + point(0, -1)
    //   fit = playfield_manager.checkFit(pos, part.type)
    //   if fit then
    //     part.pos = pos
    //   else
    //   end if
    // end
    // ```
    public func fanAnim() {
        // pos = part.pos + point(0, -1) -- stub
        // fit = playfield_manager.checkFit(pos, part.type) -- stub
        // if fit { part.pos = pos }
    }

    // Original Lingo body: fallanim
    // ```lingo
    // on fallAnim me
    //   if not playfield_manager.checkFloor(part.pos, 2) then
    //     pos = part.pos + point(0, 1)
    //     if playfield_manager.checkFit(pos, part.type) then
    //       part.pos = pos
    //     else
    //     end if
    //     if (mode <> #FALL) and (mode <> #DEAD) then
    //       SndSFX("fall")
    //       mode = #FALL
    //     end if
    //     return 1
    //   else
    //     if mode = #FALL then
    //       mode = #WALK
    //     end if
    //     return 0
    //   end if
    // end
    // ```
    public func fallAnim() -> Bool {
        // if not playfield_manager.checkFloor(part.pos, 2) -- stub
        let onFloor = true // stub
        if !onFloor {
            // pos = part.pos + point(0, 1) -- stub
            // if playfield_manager.checkFit(pos, part.type) { part.pos = pos }
            if mode != "#FALL" && mode != "#DEAD" {
                SndSFX("fall")
                mode = "#FALL"
            }
            return true
        } else {
            if mode == "#FALL" {
                mode = "#WALK"
            }
            return false
        }
    }

    // Original Lingo body: jumpanim
    // ```lingo
    // on jumpAnim me
    //   if jump_index > jump_trajectory_r.count then
    //     if mode <> #FALL then
    //       SndSFX("fall")
    //     end if
    //     mode = #FALL
    //     part[#pixelOffset] = VOID
    //   else
    //     traj = jump_trajectory_r[jump_index].duplicate()
    //     if dir = 0 then
    //       dir = (random(2) * 2) - 3
    //       put "jumping without a known direction!"
    //     end if
    //     traj.v[1] = traj.v[1] * dir
    //     traj.o[1] = traj.o[1] * dir
    //     pos = part.pos + traj.v
    //     if playfield_manager.checkFit(pos, part.type) then
    //       part.pos = pos.duplicate()
    //       part[#pixelOffset] = traj.o
    //       if playfield_manager.checkFloor(part.pos, 2) then
    //         mode = #WALK
    //         part[#pixelOffset] = VOID
    //       end if
    //     else
    //       if mode <> #FALL then
    //         SndSFX("fall")
    //         SndSFX("headbonk1")
    //       end if
    //       mode = #FALL
    //       part[#pixelOffset] = VOID
    //     end if
    //     jump_index = jump_index + 1
    //   end if
    // end
    // ```
    public func jumpAnim() {
        if jump_index > jump_trajectory_r.count {
            if mode != "#FALL" {
                SndSFX("fall")
            }
            mode = "#FALL"
            part["pixelOffset"] = .void
        } else {
            let traj = jump_trajectory_r[jump_index - 1]
            if dir == 0 {
                dir = (lingoRandom(2) * 2) - 3
                debugLog("jumping without a known direction!")
            }
            if let vList = traj["v"].asList, vList.count >= 2,
               let vx = vList[1].asInt {
                vList[1] = .int(vx * dir)
            }
            if let o = traj["o"].asPoint {
                traj["o"] = .point(x: o.x * dir, y: o.y)
            }
            // pos = part.pos + traj["v"] -- stub
            // if playfield_manager.checkFit(pos, part.type) { ... } -- stub
            jump_index += 1
        }
    }

    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   playfield_manager.erasePiece(part.pos)
    //   if ((mode = #WALK) or (mode = #FAN)) and (part.frame = 1) and not voidp(shieldticks) then
    //     if the ticks > shieldticks then
    //       SHIELD = 0
    //       SndSFX("h_powerdown3", VOID, 125)
    //       part.frame = 1
    //       frameCounter = 1
    //       shieldticks = VOID
    //     end if
    //   end if
    //   if mode = #jump then
    //     me.jumpAnim()
    //   else
    //     me.stepAnim()
    //     if fanMode then
    //       me.fanAnim()
    //     else
    //       if me.fallAnim() then
    //         nothing()
    //       end if
    //     end if
    //     if mode = #EAT then
    //       if dir < 0 then
    //         if SHIELD = 1 then
    //           part.state = #SHIELDEAT_L
    //         else
    //           part.state = #EAT_L
    //         end if
    //       else
    //         if SHIELD = 1 then
    //           part.state = #SHIELDEAT_R
    //         else
    //           part.state = #EAT_R
    //         end if
    //       end if
    //       frameMax = 19
    //       if frameCounter = frameMax then
    //         part.frame = 1
    //         frameCounter = 1
    //         mode = #WALK
    //         me.doWalkState()
    //         play_manager.addStatus(#goals, 1)
    //       end if
    //     else
    //       if (mode = #SHIELDON) or (mode = #SHIELDOFF) then
    //         if mode = #SHIELDON then
    //           frameMax = 14
    //         else
    //           frameMax = 11
    //         end if
    //         if frameCounter >= (frameMax - 1) then
    //           frameCounter = 1
    //           part.frame = 1
    //           mode = #WALK
    //           frameMax = 10
    //           me.doWalkState()
    //         end if
    //       else
    //         if ((mode = #WALK) or (mode = #FALL)) and not fanMode then
    //           frameMax = 10
    //           if mode = #WALK then
    //             if frameCounter = 6 then
    //               step(me)
    //             else
    //               if frameCounter = 1 then
    //                 step(me)
    //               end if
    //             end if
    //           end if
    //           if 1 or not voidp(shieldticks) then
    //             me.doWalkState()
    //           end if
    //         else
    //           if mode = #DEAD then
    //             frameMax = 13
    //             if frameCounter >= (frameMax - 1) then
    //               part.frame = 1
    //               frameCounter = 1
    //               frameMax = 1
    //               part.state = #DEAD_STILL
    //               play_manager.addStatus(#damage, 1)
    //             end if
    //           end if
    //         end if
    //       end if
    //     end if
    //   end if
    //   if part.frame > frameMax then
    //     part.frame = frameMax
    //   end if
    //   playfield_manager.placePiece(part)
    //   fanMode = 0
    // end
    // ```
    public func stepFrame() {
        // playfield_manager.erasePiece(part.pos) -- stub
        let ticks = currentTicks
        let frame = part["frame"].asInt ?? 0
        if (mode == "#WALK" || mode == "#FAN") && (frame == 1) && shieldticks != nil {
            if let st = shieldticks, ticks > st {
                SHIELD = 0
                SndSFX("h_powerdown3", sfxpan: 0, sfxlevel: 125)
                part["frame"] = .int(1)
                frameCounter = 1
                shieldticks = nil
            }
        }
        if mode == "#jump" {
            jumpAnim()
        } else {
            stepAnim()
            if fanMode != 0 {
                fanAnim()
            } else {
                if fallAnim() {
                    // nothing
                }
            }
            if mode == "#EAT" {
                if dir < 0 {
                    if SHIELD == 1 {
                        part["state"] = .string("#SHIELDEAT_L")
                    } else {
                        part["state"] = .string("#EAT_L")
                    }
                } else {
                    if SHIELD == 1 {
                        part["state"] = .string("#SHIELDEAT_R")
                    } else {
                        part["state"] = .string("#EAT_R")
                    }
                }
                frameMax = 19
                if frameCounter == frameMax {
                    part["frame"] = .int(1)
                    frameCounter = 1
                    mode = "#WALK"
                    doWalkState()
                    play_manager?.addStatus("#goals", 1)
                }
            } else if mode == "#SHIELDON" || mode == "#SHIELDOFF" {
                if mode == "#SHIELDON" {
                    frameMax = 14
                } else {
                    frameMax = 11
                }
                if frameCounter >= (frameMax - 1) {
                    frameCounter = 1
                    part["frame"] = .int(1)
                    mode = "#WALK"
                    frameMax = 10
                    doWalkState()
                }
            } else if (mode == "#WALK" || mode == "#FALL") && fanMode == 0 {
                frameMax = 10
                if mode == "#WALK" {
                    if frameCounter == 6 {
                        step()
                    } else if frameCounter == 1 {
                        step()
                    }
                }
                doWalkState()
            } else if mode == "#DEAD" {
                frameMax = 13
                if frameCounter >= (frameMax - 1) {
                    part["frame"] = .int(1)
                    frameCounter = 1
                    frameMax = 1
                    part["state"] = .string("#DEAD_STILL")
                    play_manager?.addStatus("#damage", 1)
                }
            }
        }
        if let fr = part["frame"].asInt, fr > frameMax {
            part["frame"] = .int(frameMax)
        }
        // playfield_manager.placePiece(part) -- stub
        fanMode = 0
    }
}
