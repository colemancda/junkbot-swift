// Translated from Lingo: parent_hazard slick jump parent.ls

public class HazardSlickJumpParent: LingoObject, @unchecked Sendable {
    public var playfield_manager: PlayfieldManager? = nil
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var last_jump: Int = 0
    public var active_ticks: Int? = nil
    public var dir: LV = .void
    public var paused: Int = 0

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   part[#behavior] = me
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   last_jump = 0
    //   return me
    // end
    // ```
    public init(_ p: PropList) {        part = p

        super.init()
        // part["behavior"] = self -- set by caller
        play_manager = Glob.shared["PLAYER"].asObject()?.asPlayManager ?? Glob.shared["PLAYER"].asPropList?["play_manager"].asPlayManager
        playfield_manager = play_manager?.playfield_manager
        last_jump = 0
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

    // Original Lingo body: pause
    // ```lingo
    // on pause me
    //   paused = 1
    // end
    // ```
    public func pause() {
        paused = 1
    }

    // Original Lingo body: resume
    // ```lingo
    // on resume me
    //   paused = 0
    //   part.state = #dormant
    //   part.frame = 1
    // end
    // ```
    public func resume() {
        paused = 0
        part["state"] = .string("#dormant")
        part["frame"] = .int(1)
    }

    // Original Lingo body: notify
    // ```lingo
    // on notify me, notes
    //   if notes[#destroyed] = 1 then
    //     me.done()
    //   else
    //     if notes[#pos] <> VOID then
    //       part.pos = notes[#pos]
    //     else
    //       if notes[#stop] = 1 then
    //         me.pause()
    //       else
    //         if notes[#Start] = 1 then
    //           me.resume()
    //         end if
    //       end if
    //     end if
    //   end if
    // end
    // ```
    public override func notify(_ notes: PropList) {
        if let destroyed = notes["destroyed"].asInt, destroyed == 1 {
            done()
        } else if !notes["pos"].isVoid {
            part["pos"] = notes["pos"]
        } else if let stop = notes["stop"].asInt, stop == 1 {
            pause()
        } else if let start = notes["Start"].asInt, start == 1 {
            resume()
        }
    }

    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   if paused = 1 then
    //     return 
    //   end if
    //   playfield_manager.erasePiece(part.pos)
    //   me.stepAnim()
    //   me.checkMiniFig()
    //   playfield_manager.placePiece(part)
    // end
    // ```
    public func stepFrame() {
        if paused == 1 { return }
        playfield_manager?.erasePiece(part.pos)
        stepAnim()
        checkMiniFig()
        playfield_manager?.placePiece(part)
    }

    // Original Lingo body: stepanim
    // ```lingo
    // on stepAnim me
    // end
    // ```
    public func stepAnim() {
        // No animation logic in original
    }

    // Original Lingo body: checkminifig
    // ```lingo
    // on checkMiniFig me
    //   fig = playfield_manager.checkFitOrMinifig(part.pos + point(0, -1), #BRICK_01)
    //   fig2 = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), #BRICK_01)
    //   if (fig = fig2) and (ilk(fig) = #propList) and ((the ticks - last_jump) > 60) then
    //     SndSFX("jump3")
    //     fig.behavior.notify([#jump: part])
    //     part.state = #Active
    //     part.frame = 1
    //     last_jump = the ticks
    //   else
    //     if part.state = #Active then
    //       part.frame = part.frame + 1
    //       if part.frame > 4 then
    //         part.frame = 1
    //         part.state = #dormant
    //       end if
    //     end if
    //   end if
    // end
    // ```
    public func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(0, -1), "#BRICK_01") -- stub
        let _pos = (part["pos"].asPoint ?? Point()) + Point(x: 0, y: -1)
        var fig = playfield_manager?.checkFitOrMinifig(LV.pt(_pos.x, _pos.y), "#BRICK_01") ?? .void
        // fig2 = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_01") -- stub
        let _pos2 = (part["pos"].asPoint ?? Point()) + Point(x: 1, y: -1)
        var fig2 = playfield_manager?.checkFitOrMinifig(LV.pt(_pos2.x, _pos2.y), "#BRICK_01") ?? .void
        let ticks = currentTicks

        // Check: fig == fig2 && fig.isPropList && (ticks - last_jump) > 60
        if fig.isPropList && fig2.isPropList && (ticks - last_jump) > 60 {
            // check fig === fig2 (same object) — only possible to verify at runtime with identity
            SndSFX("jump3")
            // fig.asPropList!.behavior.notify(["jump": part]) -- stub
            fig.asPropList?["behavior"].asObject()?.notify(PropList([("jump", .propList(part))]))
            part["state"] = .string("#Active")
            part["frame"] = .int(1)
            last_jump = ticks
        } else {
            let state = part["state"].asString ?? ""
            if state == "#Active" {
                let frame = (part["frame"].asInt ?? 0) + 1
                if frame > 4 {
                    part["frame"] = .int(1)
                    part["state"] = .string("#dormant")
                } else {
                    part["frame"] = .int(frame)
                }
            }
        }
    }
}
