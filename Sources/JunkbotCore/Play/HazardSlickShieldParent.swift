// Translated from Lingo: parent_hazard slick shield parent.ls

public class HazardSlickShieldParent {
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
        // No-op in original
    }

    public func done() {
        if let pm = play_manager { pm.actorDone(self) }
    }

    public func stepFrame() {
        let state = part["state"].asString ?? ""
        if state == "#on" {
            checkMiniFig()
        }
    }

    public func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(0, -1), "#BRICK_01") -- stub
        let fig: LV = .void // stub
        // fig2 = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_01") -- stub
        let fig2: LV = .void // stub

        // (fig == fig2) && fig.isPropList
        if fig.isPropList && fig2.isPropList {
            // check fig === fig2 (same object) at runtime
            // fig.asPropList!.behavior.notify(["SHIELD": 1]) -- stub
            part["state"] = .string("#off")
            redrawPart()
        }
    }

    public func redrawPart() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // playfield_manager.placePiece(part) -- stub
    }
}
