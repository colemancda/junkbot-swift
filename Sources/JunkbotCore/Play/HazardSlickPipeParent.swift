// Translated from Lingo: parent_hazard slick pipe parent.ls

public class HazardSlickPipeParent: LingoObject, @unchecked Sendable {
    public var playfield_manager: PlayfieldManager? = nil
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var last_step: Int = 0
    public var last_drip: Int = 0
    public var drip_cycle: Int = 1
    public var myDrip: HazardDripParent? = nil
    public var dir: LV = .void

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   part[#behavior] = me
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   part[#auxSprites] = [:]
    //   myWidth = 2
    //   last_step = the ticks
    //   last_drip = the ticks + random(240)
    //   drip_cycle = random(3)
    //   return me
    // end
    // ```
    public init(_ p: PropList) {        part = p

        super.init()
        // part["behavior"] = self -- set by caller
        play_manager = Glob.shared["PLAYER"].asObject()?.asPlayManager ?? Glob.shared["PLAYER"].asPropList?["play_manager"].asPlayManager
        playfield_manager = play_manager?.playfield_manager
        part["auxSprites"] = .propList(PropList())
        myWidth = 2
        let ticks = currentTicks
        last_step = ticks
        last_drip = ticks + lingoRandom(240)
        drip_cycle = lingoRandom(3)
    }

    // Original Lingo body: done
    // ```lingo
    // on done me
    //   play_manager.actorDone(me)
    //   if not voidp(myDrip) then
    //     myDrip.done(me)
    //   end if
    // end
    // ```
    public func done() {
        if let pm = play_manager { pm.actorDone(self) }
        myDrip?.done()
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

    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   playfield_manager.erasePiece(part.pos)
    //   me.stepAnim()
    //   if not voidp(myDrip) then
    //     myDrip.stepFrame()
    //   end if
    //   playfield_manager.placePiece(part)
    // end
    // ```
    public func stepFrame() {
        playfield_manager?.erasePiece(part.pos)
        stepAnim()
        myDrip?.stepFrame()
        playfield_manager?.placePiece(part)
    }

    // Original Lingo body: stepanim
    // ```lingo
    // on stepAnim me
    //   t = the ticks
    //   case part.state of
    //     #DRY:
    //       if drip_cycle = 1 then
    //         drip_time = 160 + random(40)
    //       else
    //         drip_time = 80 + random(20)
    //       end if
    //       if ((t - last_drip) > drip_time) and voidp(myDrip) then
    //         part.state = #wet
    //         last_drip = t
    //         drip_cycle = drip_cycle + 1
    //         if drip_cycle = 4 then
    //           drip_cycle = 1
    //         end if
    //       end if
    //       part.frame = 1
    //     #wet:
    //       part.frame = part.frame + 1
    //       if part.frame = 8 then
    //         part.frame = 1
    //         part.state = #DRY
    //         myDrip = new(script("hazard drip parent"), me, part)
    //       end if
    //   end case
    // end
    // ```
    public func stepAnim() {
        let t = currentTicks
        let state = part["state"].asString ?? ""
        switch state {
        case "#DRY":
            let drip_time: Int
            if drip_cycle == 1 {
                drip_time = 160 + lingoRandom(40)
            } else {
                drip_time = 80 + lingoRandom(20)
            }
            if ((t - last_drip) > drip_time) && myDrip == nil {
                part["state"] = .string("#wet")
                last_drip = t
                drip_cycle += 1
                if drip_cycle == 4 {
                    drip_cycle = 1
                }
            }
            part["frame"] = .int(1)
        case "#wet":
            let frame = (part["frame"].asInt ?? 0) + 1
            if frame == 8 {
                part["frame"] = .int(1)
                part["state"] = .string("#DRY")
                myDrip = HazardDripParent(self, part)
            } else {
                part["frame"] = .int(frame)
            }
        default:
            break
        }
    }

    // Original Lingo body: dripdone
    // ```lingo
    // on dripDone me, d
    //   myDrip = VOID
    // end
    // ```
    public func dripDone(_ d: HazardDripParent) {
        myDrip = nil
    }

    // Original Lingo body: checkminifig
    // ```lingo
    // on checkMiniFig me
    //   fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), #BRICK_02)
    //   if ilk(fig) = #propList then
    //     SndSFX("fire")
    //     fig.behavior.notify([#damage: #drip])
    //   end if
    // end
    // ```
    public func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_02") -- stub
        let fig: LV = .void // stub
        if fig.isPropList {
            SndSFX("fire")
            // fig.asPropList!.behavior.notify(["damage": "#drip"]) -- stub
        }
    }
}
