// Translated from Lingo: parent_hazard slick switch parent.ls

public class HazardSlickSwitchParent {
    public var play_manager: PlayManager? = nil
    public var playfield_manager: LV = .void
    public var part: PropList
    public var stepped_on: Int = 0

    public init(_ p: PropList) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        stepped_on = 0
    }

    public func notify(_ args: PropList) {
        if !args["switch"].isVoid {
            part["state"] = args["switch"]
            redrawPart()
        }
    }

    public func done() {
        if let pm = play_manager { pm.actorDone(self) }
    }

    public func stepFrame() {
        checkMiniFig()
    }

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

    public func redrawPart() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // playfield_manager.placePiece(part) -- stub
    }
}
