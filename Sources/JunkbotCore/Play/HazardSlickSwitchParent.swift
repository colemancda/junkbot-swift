// Translated from Lingo: parent_hazard slick switch parent.ls

public class HazardSlickSwitchParent: LingoObject, @unchecked Sendable {
    public var play_manager: PlayManager? = nil
    public var playfield_manager: LV = .void
    public var part: PropList
    public var stepped_on: Int = 0

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   part[#behavior] = me
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   stepped_on = 0
    //   return me
    // end
    // ```
    public init(_ p: PropList) {
        super.init()
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        stepped_on = 0
    }

    // Original Lingo body: notify
    // ```lingo
    // on notify me, args
    //   if not voidp(args[#switch]) then
    //     part.state = args[#switch]
    //     me.redrawPart()
    //   end if
    // end
    // ```
    public override func notify(_ args: PropList) {
        if !args["switch"].isVoid {
            part["state"] = args["switch"]
            redrawPart()
        }
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

    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   me.checkMiniFig()
    // end
    // ```
    public func stepFrame() {
        checkMiniFig()
    }

    // Original Lingo body: checkminifig
    // ```lingo
    // on checkMiniFig me
    //   fig = playfield_manager.checkFitOrMinifig(part.pos + point(0, -1), #BRICK_01)
    //   fig2 = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), #BRICK_01)
    //   if (fig = fig2) and (ilk(fig) = #propList) then
    //     if not stepped_on then
    //       stepped_on = 1
    //       if part.state = #off then
    //         part.state = #on
    //         SndSFX("switch_on")
    //         SndSFX("switch_click")
    //       else
    //         part.state = #off
    //         SndSFX("switch_off")
    //         SndSFX("switch_click")
    //       end if
    //       play_manager.doSwitch([#label: part.label, #state: part.state])
    //       part.frame = 1
    //     end if
    //   else
    //     stepped_on = 0
    //   end if
    // end
    // ```
    public func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(0, -1), "#BRICK_01") -- stub
        let fig: LV = .void // stub
        // fig2 = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_01") -- stub
        let fig2: LV = .void // stub

        // (fig == fig2) && fig.isPropList
        if fig.isPropList && fig2.isPropList {
            // check fig === fig2 (same object) at runtime
            if stepped_on == 0 {
                stepped_on = 1
                let state = part["state"].asString ?? ""
                if state == "#off" {
                    part["state"] = .string("#on")
                    SndSFX("switch_on")
                    SndSFX("switch_click")
                } else {
                    part["state"] = .string("#off")
                    SndSFX("switch_off")
                    SndSFX("switch_click")
                }
                let label = part["label"].asString ?? ""
                var args = PropList()
                args["label"] = .string(label)
                args["state"] = part["state"]
                play_manager?.doSwitch(args)
                part["frame"] = .int(1)
            }
        } else {
            stepped_on = 0
        }
    }

    // Original Lingo body: redrawpart
    // ```lingo
    // on redrawPart me
    //   playfield_manager.erasePiece(part.pos)
    //   playfield_manager.placePiece(part)
    // end
    // ```
    public func redrawPart() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // playfield_manager.placePiece(part) -- stub
    }
}
