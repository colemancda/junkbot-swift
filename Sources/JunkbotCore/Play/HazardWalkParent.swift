// Translated from Lingo: parent_hazard walk parent.ls

public class HazardWalkParent {
    public var playfield_manager: LV = .void
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var speed: Int = 4
    public var last_step: Int = 0
    public var dir: Int = 1

    public init(_ p: PropList) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
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

    public func done() {
        if let pm = play_manager { pm.actorDone(self) }
    }

    public func notify(_ notes: PropList) {
        if let destroyed = notes["destroyed"].asInt, destroyed == 1 {
            done()
        } else if !notes["pos"].isVoid {
            part["pos"] = notes["pos"]
        }
    }

    public func step() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // pos = part.pos + point(dir, 0) -- stub
        var ok = false
        // fg = playfield_manager.checkFitOrMinifig(pos, part.type) -- stub
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
        // if fg.isPropList { SndSFX("robottouch4"); fg.behavior.notify(["damage": "#walker"]) } -- stub
        // playfield_manager.placePiece(part) -- stub
    }

    public func stepAnim() {
        let frame = part["frame"].asInt ?? 1
        if frame == 1 {
            part["frame"] = .int(2)
        } else {
            part["frame"] = .int(1)
        }
    }

    public func stepFrame() {
        if let frame = part["frame"].asInt, frame == 2 {
            step()
        }
        // playfield_manager.erasePiece(part.pos) -- stub
        stepAnim()
        // playfield_manager.placePiece(part) -- stub
    }
}
