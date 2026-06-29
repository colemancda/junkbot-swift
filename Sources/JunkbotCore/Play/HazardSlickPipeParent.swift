// Translated from Lingo: parent_hazard slick pipe parent.ls

public class HazardSlickPipeParent {
    public var playfield_manager: LV = .void
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var last_step: Int = 0
    public var last_drip: Int = 0
    public var drip_cycle: Int = 1
    public var myDrip: HazardDripParent? = nil
    public var dir: LV = .void

    public init(_ p: PropList) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        part["auxSprites"] = .propList(PropList())
        myWidth = 2
        let ticks = currentTicks
        last_step = ticks
        last_drip = ticks + lingoRandom(240)
        drip_cycle = lingoRandom(3)
    }

    public func done() {
        if let pm = play_manager { pm.actorDone(self) }
        myDrip?.done()
    }

    public func notify(_ notes: PropList) {
        if let destroyed = notes["destroyed"].asInt, destroyed == 1 {
            done()
        } else if !notes["pos"].isVoid {
            part["pos"] = notes["pos"]
        }
    }

    public func stepFrame() {
        // playfield_manager.erasePiece(part.pos) -- stub
        stepAnim()
        myDrip?.stepFrame()
        // playfield_manager.placePiece(part) -- stub
    }

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

    public func dripDone(_ d: HazardDripParent) {
        myDrip = nil
    }

    public func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_02") -- stub
        let fig: LV = .void // stub
        if fig.isPropList {
            SndSFX("fire")
            // fig.asPropList!.behavior.notify(["damage": "#drip"]) -- stub
        }
    }
}
