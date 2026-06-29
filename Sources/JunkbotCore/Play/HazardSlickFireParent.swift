// Translated from Lingo: parent_hazard slick fire parent.ls

public class HazardSlickFireParent {
    public var playfield_manager: LV = .void
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var last_step: Int = 0
    public var dir: LV = .void

    public init(_ p: PropList) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        myWidth = 2
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
        } else if !notes["switch"].isVoid {
            part["state"] = notes["switch"]
            stepAnim()
            updatePart()
        }
    }

    public func stepFrame() {
        stepAnim()
        updatePart()
        let state = part["state"].asString ?? ""
        if state == "#on" {
            checkMiniFig()
        }
    }

    public func updatePart() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // playfield_manager.placePiece(part) -- stub
    }

    public func stepAnim() {
        let state = part["state"].asString ?? ""
        if state == "#on" {
            let frame = part["frame"].asInt ?? 1
            part["frame"] = .int((frame % 7) + 1)
        } else {
            part["frame"] = .int(1)
        }
    }

    public func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_02") -- stub
        let fig: LV = .void // stub
        if fig.isPropList {
            SndSFX("fire")
            // fig.asPropList!.behavior.notify(["damage": "#fire"]) -- stub
        }
    }
}
