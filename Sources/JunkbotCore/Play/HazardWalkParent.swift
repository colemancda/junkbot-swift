// Translated from Lingo: parent_hazard walk parent.ls

public class HazardWalkParent: LingoObject, @unchecked Sendable {
    public var playfield_manager: PlayfieldManager? = nil
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var speed: Int = 4
    public var last_step: Int = 0
    public var dir: Int = 1

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   part[#behavior] = me
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   myWidth = 2
    //   if part.state = "WALK_L" then
    //     dir = -1
    //   else
    //     dir = 1
    //   end if
    //   speed = 4
    //   last_step = the ticks
    //   return me
    // end
    // ```
    public init(_ p: PropList) {        part = p

        super.init()
        // part["behavior"] = self -- set by caller
        play_manager = Glob.shared["PLAYER"].asObject()?.asPlayManager ?? Glob.shared["PLAYER"].asPropList()?["play_manager"]?.asPlayManager
        playfield_manager = play_manager?.playfield_manager
        myWidth = 2
        let state = p["state"].asString ?? ""
        if state == "WALK_L" {
            dir = -1
        } else {
            dir = 1
        }
        speed = 4
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
    //   playfield_manager.erasePiece(part.pos)
    //   pos = part.pos + point(dir, 0)
    //   Ok = 0
    //   fg = playfield_manager.checkFitOrMinifig(pos, part.type)
    //   if fg = 1 then
    //     ms = the milliSeconds
    //     if playfield_manager.checkFloor(pos, myWidth) > 1 then
    //       Ok = 1
    //       part.pos = pos
    //     end if
    //   end if
    //   if not Ok then
    //     dir = -dir
    //     if dir > 0 then
    //       part.state = #WALK_R
    //     else
    //       part.state = #walk_l
    //     end if
    //   end if
    //   if ilk(fg) = #propList then
    //     SndSFX("robottouch4")
    //     fg.behavior.notify([#damage: #walker])
    //   end if
    //   playfield_manager.placePiece(part)
    // end
    // ```
    public func step() {
        playfield_manager?.erasePiece(part.pos)
        pos = (part["pos"].asPoint ?? Point()) + Point(x: dir, y: 0)
        var ok = false
        var fg = playfield_manager?.checkFitOrMinifig(pos, part.type) ?? .void
        let fg: LV = .void
        _ = fg

        // if fg == 1 { if playfield_manager.checkFloor(pos, myWidth) > 1 { ok = true; part.pos = pos } }
        if !ok {
            dir = -dir
            if dir > 0 {
                part["state"] = .string("#WALK_R")
            } else {
                part["state"] = .string("#walk_l")
            }
        }
        if fg.isPropList { SndSFX("robottouch4"); fg.asPropList()?["behavior"].asObject()?.notify(["damage": .string("#walker")]) }
        playfield_manager?.placePiece(.propList(part))
    }

    // Original Lingo body: stepanim
    // ```lingo
    // on stepAnim me
    //   if part.frame = 1 then
    //     part.frame = 2
    //   else
    //     part.frame = 1
    //   end if
    // end
    // ```
    public func stepAnim() {
        let frame = part["frame"].asInt ?? 1
        if frame == 1 {
            part["frame"] = .int(2)
        } else {
            part["frame"] = .int(1)
        }
    }

    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   if part.frame = 2 then
    //     step(me)
    //   end if
    //   playfield_manager.erasePiece(part.pos)
    //   me.stepAnim()
    //   playfield_manager.placePiece(part)
    // end
    // ```
    public func stepFrame() {
        if let frame = part["frame"].asInt, frame == 2 {
            step()
        }
        playfield_manager?.erasePiece(part.pos)
        stepAnim()
        playfield_manager?.placePiece(.propList(part))
    }
}
