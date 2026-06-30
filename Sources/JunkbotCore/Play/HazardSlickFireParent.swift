// Translated from Lingo: parent_hazard slick fire parent.ls

public class HazardSlickFireParent: LingoObject, @unchecked Sendable {
    public var playfield_manager: PlayfieldManager? = nil
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var last_step: Int = 0
    public var dir: LV = .void

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   part[#behavior] = me
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   myWidth = 2
    //   last_step = the ticks
    //   return me
    // end
    // ```
    public init(_ p: PropList) {        part = p

        super.init()
        // part["behavior"] = self -- set by caller
        play_manager = Glob.shared["PLAYER"].asObject()?.asPlayManager ?? Glob.shared["PLAYER"].asPropList?["play_manager"].asPlayManager
        playfield_manager = play_manager?.playfield_manager
        myWidth = 2
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
    //     if not voidp(notes[#pos]) then
    //       part.pos = notes[#pos]
    //     else
    //       if not voidp(notes[#switch]) then
    //         part.state = notes[#switch]
    //         me.stepAnim()
    //         me.updatePart()
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
        } else if !notes["switch"].isVoid {
            part["state"] = notes["switch"]
            stepAnim()
            updatePart()
        }
    }

    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   me.stepAnim()
    //   me.updatePart()
    //   if part.state = #on then
    //     me.checkMiniFig()
    //   end if
    // end
    // ```
    public func stepFrame() {
        stepAnim()
        updatePart()
        let state = part["state"].asString ?? ""
        if state == "#on" {
            checkMiniFig()
        }
    }

    // Original Lingo body: updatepart
    // ```lingo
    // on updatePart me
    //   playfield_manager.erasePiece(part.pos)
    //   playfield_manager.placePiece(part)
    // end
    // ```
    public func updatePart() {
        playfield_manager?.erasePiece(part.pos)
        playfield_manager?.placePiece(part)
    }

    // Original Lingo body: stepanim
    // ```lingo
    // on stepAnim me
    //   if part.state = #on then
    //     part.frame = (part.frame mod 7) + 1
    //   else
    //     part.frame = 1
    //   end if
    // end
    // ```
    public func stepAnim() {
        let state = part["state"].asString ?? ""
        if state == "#on" {
            let frame = part["frame"].asInt ?? 1
            part["frame"] = .int((frame % 7) + 1)
        } else {
            part["frame"] = .int(1)
        }
    }

    // Original Lingo body: checkminifig
    // ```lingo
    // on checkMiniFig me
    //   fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), #BRICK_02)
    //   if ilk(fig) = #propList then
    //     SndSFX("fire")
    //     fig.behavior.notify([#damage: #fire])
    //   end if
    // end
    // ```
    public func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_02") -- stub
        let _pos = (part["pos"].asPoint ?? Point()) + Point(x: 1, y: -1)
        var fig = playfield_manager?.checkFitOrMinifig(LV.pt(_pos.x, _pos.y), "#BRICK_02") ?? .void
        if fig.isPropList {
            SndSFX("fire")
            // fig.asPropList!.behavior.notify(["damage": "#fire"]) -- stub
            fig.asPropList?["behavior"].asObject()?.notify(PropList([("damage", .string("#fire"))]))
        }
    }
}
