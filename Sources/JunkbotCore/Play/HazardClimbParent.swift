// Translated from Lingo: parent_hazard climb parent.ls

public class HazardClimbParent: LingoObject, @unchecked Sendable {
    public var playfield_manager: LV = .void
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var speed: Int = 4
    public var climb_up: Int = 3
    public var jump_over: Int = 1
    public var last_step: Int = 0
    public var dir: Point = Point(x: 1, y: 0)
    public var climbstart: Int = 0
    public var oldhoriz: Int = 1

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   part[#behavior] = me
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   myWidth = 2
    //   if part.state = #walk_l then
    //     dir = point(-1, 0)
    //   else
    //     if part.state = #WALK_R then
    //       dir = point(1, 0)
    //     else
    //       if part.state = #FLOAT_UP then
    //         dir = point(0, -1)
    //       else
    //         dir = point(0, 1)
    //       end if
    //     end if
    //   end if
    //   oldhoriz = 1
    //   speed = 4
    //   climb_up = 3
    //   jump_over = 1
    //   climbstart = part.pos[2]
    //   last_step = the ticks
    //   return me
    // end
    // ```
    public init(_ p: PropList) {
        super.init()
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        myWidth = 2
        let state = p["state"].asString ?? ""
        if state == "#walk_l" {
            dir = Point(x: -1, y: 0)
        } else if state == "#WALK_R" {
            dir = Point(x: 1, y: 0)
        } else if state == "#FLOAT_UP" {
            dir = Point(x: 0, y: -1)
        } else {
            dir = Point(x: 0, y: 1)
        }
        oldhoriz = 1
        speed = 4
        climb_up = 3
        jump_over = 1
        climbstart = p["pos"].asPoint?.y ?? 0
        last_step = currentTicks
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
    //     if notes[#pos] <> VOID then
    //       part.pos = notes[#pos]
    //     end if
    //   end if
    // end
    // ```
    public override func notify(_ notes: PropList) {
        if let destroyed = notes["destroyed"].asInt, destroyed == 1 {
            done()
        } else if !notes["pos"].isVoid {
            part["pos"] = notes["pos"]
        }
    }

    // Original Lingo body: step
    // ```lingo
    // on step me
    //   glob.PLAYER[#minifigHit] = VOID
    //   playfield_manager.erasePiece(part.pos)
    //   case part.state of
    //     #FLOAT_UP:
    //       tdir = point(oldhoriz, 0)
    //       if (part.pos[2] = climbstart) and playfield_manager.checkFitMiniFigHit(part.pos + dir, part.type) then
    //         part.pos = part.pos + dir
    //       else
    //         if playfield_manager.checkFitMiniFigHit(part.pos + tdir, part.type) and (playfield_manager.checkFloor(part.pos + tdir, myWidth) > 0) then
    //           dir = tdir
    //           part.pos = part.pos + dir
    //         else
    //           if playfield_manager.checkFitMiniFigHit(part.pos - tdir, part.type) and (playfield_manager.checkFloor(part.pos - tdir, myWidth) > 0) then
    //             dir = -tdir
    //             part.pos = part.pos + dir
    //           else
    //             if (climbstart - part.pos[2]) >= climb_up then
    //               dir = -dir
    //             else
    //               if playfield_manager.checkFitMiniFigHit(part.pos + dir, part.type) then
    //                 part.pos = part.pos + dir
    //               else
    //                 dir = -dir
    //               end if
    //             end if
    //           end if
    //         end if
    //       end if
    //     #FLOAT_DOWN:
    //       tdir = point(oldhoriz, 0)
    //       if playfield_manager.checkFitMiniFigHit(part.pos + dir, part.type) then
    //         part.pos = part.pos + dir
    //       else
    //         if playfield_manager.checkFitMiniFigHit(part.pos + tdir, part.type) then
    //           dir = tdir
    //           part.pos = part.pos + dir
    //         else
    //           if playfield_manager.checkFitMiniFigHit(part.pos - tdir, part.type) then
    //             dir = -tdir
    //             part.pos = part.pos + dir
    //           else
    //             dir = point(0, -1)
    //             climbstart = part.pos[2]
    //           end if
    //         end if
    //       end if
    //     #walk_l, #WALK_R:
    //       if (playfield_manager.checkFloor(part.pos, myWidth) = 0) and playfield_manager.checkFitMiniFigHit(part.pos + point(0, 1), part.type) then
    //         oldhoriz = dir[1]
    //         dir = point(0, 1)
    //         part.pos = part.pos + dir
    //       else
    //         if not playfield_manager.checkFitMiniFigHit(part.pos + dir, part.type) then
    //           oldhoriz = dir[1]
    //           dir = point(0, -1)
    //           climbstart = part.pos[2]
    //         else
    //           part.pos = part.pos + dir
    //         end if
    //       end if
    //   end case
    //   if dir[1] < 0 then
    //     part.state = #walk_l
    //   else
    //     if dir[1] > 0 then
    //       part.state = #WALK_R
    //     else
    //       if dir[2] < 0 then
    //         part.state = #FLOAT_UP
    //       else
    //         part.state = #FLOAT_DOWN
    //       end if
    //     end if
    //   end if
    //   if not voidp(glob.PLAYER[#minifigHit]) then
    //     SndSFX("robottouch4")
    //     glob.PLAYER[#minifigHit].behavior.notify([#damage: #climber])
    //   end if
    //   playfield_manager.placePiece(part)
    // end
    // ```
    public func step() {
        Glob.shared["minifigHit"] = .void
        // playfield_manager.erasePiece(part.pos) -- stub
        let state = part["state"].asString ?? ""
        let partPos = part["pos"].asPoint ?? Point()

        switch state {
        case "#FLOAT_UP":
            let tdir = Point(x: oldhoriz, y: 0)
            // complex movement logic — see Lingo source for full details
            // if (partPos.y == climbstart) && playfield_manager.checkFitMiniFigHit(partPos + dir, part.type) {
            //     part.pos = partPos + dir
            // } else if playfield_manager.checkFitMiniFigHit(partPos + tdir, part.type) && playfield_manager.checkFloor(partPos + tdir, myWidth) > 0 {
            //     dir = tdir; part.pos = partPos + dir
            // } else if playfield_manager.checkFitMiniFigHit(partPos - tdir, part.type) && playfield_manager.checkFloor(partPos - tdir, myWidth) > 0 {
            //     dir = Point(x: -tdir.x, y: -tdir.y); part.pos = partPos + dir
            // } else if (climbstart - partPos.y) >= climb_up {
            //     dir = Point(x: -dir.x, y: -dir.y)
            // } else if playfield_manager.checkFitMiniFigHit(partPos + dir, part.type) {
            //     part.pos = partPos + dir
            // } else {
            //     dir = Point(x: -dir.x, y: -dir.y)
            // }
            _ = tdir
        case "#FLOAT_DOWN":
            let tdir = Point(x: oldhoriz, y: 0)
            // if playfield_manager.checkFitMiniFigHit(partPos + dir, part.type) {
            //     part.pos = partPos + dir
            // } else if playfield_manager.checkFitMiniFigHit(partPos + tdir, part.type) {
            //     dir = tdir; part.pos = partPos + dir
            // } else if playfield_manager.checkFitMiniFigHit(partPos - tdir, part.type) {
            //     dir = Point(x: -tdir.x, y: -tdir.y); part.pos = partPos + dir
            // } else {
            //     dir = Point(x: 0, y: -1); climbstart = partPos.y
            // }
            _ = tdir
        case "#walk_l", "#WALK_R":
            // if playfield_manager.checkFloor(partPos, myWidth) == 0 && playfield_manager.checkFitMiniFigHit(partPos + Point(x:0,y:1), part.type) {
            //     oldhoriz = dir.x; dir = Point(x:0, y:1); part.pos = partPos + dir
            // } else if !playfield_manager.checkFitMiniFigHit(partPos + dir, part.type) {
            //     oldhoriz = dir.x; dir = Point(x:0, y:-1); climbstart = partPos.y
            // } else {
            //     part.pos = partPos + dir
            // }
            break
        default:
            break
        }

        _ = partPos

        if dir.x < 0 {
            part["state"] = .string("#walk_l")
        } else if dir.x > 0 {
            part["state"] = .string("#WALK_R")
        } else if dir.y < 0 {
            part["state"] = .string("#FLOAT_UP")
        } else {
            part["state"] = .string("#FLOAT_DOWN")
        }

        if !Glob.shared["minifigHit"].isVoid {
            SndSFX("robottouch4")
            // Glob.shared["minifigHit"].behavior.notify(["damage": "#climber"]) -- stub
        }
        // playfield_manager.placePiece(part) -- stub
    }

    // Original Lingo body: stepanim
    // ```lingo
    // on stepAnim me
    //   part.frame = (part.frame mod 6) + 1
    // end
    // ```
    public func stepAnim() {
        let frame = part["frame"].asInt ?? 0
        part["frame"] = .int((frame % 6) + 1)
    }

    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   if part.frame = 6 then
    //     step(me)
    //   end if
    //   playfield_manager.erasePiece(part.pos)
    //   me.stepAnim()
    //   playfield_manager.placePiece(part)
    // end
    // ```
    public func stepFrame() {
        if let frame = part["frame"].asInt, frame == 6 {
            step()
        }
        // playfield_manager.erasePiece(part.pos) -- stub
        stepAnim()
        // playfield_manager.placePiece(part) -- stub
    }
}
