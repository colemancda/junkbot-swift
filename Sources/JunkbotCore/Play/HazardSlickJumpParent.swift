// Translated from Lingo: parent_hazard slick jump parent.ls

public class HazardSlickJumpParent {
    public var playfield_manager: LV = .void
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var last_jump: Int = 0
    public var active_ticks: Int? = nil
    public var dir: LV = .void
    public var paused: Int = 0

    public init(_ p: PropList) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        last_jump = 0
    }

    public func done() {
        if let pm = play_manager { pm.actorDone(self) }
    }

    public func pause() {
        paused = 1
    }

    public func resume() {
        paused = 0
        part["state"] = .string("#dormant")
        part["frame"] = .int(1)
    }

    public func notify(_ notes: PropList) {
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

    public func stepFrame() {
        if paused == 1 { return }
        // playfield_manager.erasePiece(part.pos) -- stub
        stepAnim()
        checkMiniFig()
        // playfield_manager.placePiece(part) -- stub
    }

    public func stepAnim() {
        // No animation logic in original
    }

    public func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(0, -1), "#BRICK_01") -- stub
        let fig: LV = .void // stub
        // fig2 = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_01") -- stub
        let fig2: LV = .void // stub
        let ticks = currentTicks

        // Check: fig == fig2 && fig.isPropList && (ticks - last_jump) > 60
        if fig.isPropList && fig2.isPropList && (ticks - last_jump) > 60 {
            // check fig === fig2 (same object) — only possible to verify at runtime with identity
            SndSFX("jump3")
            // fig.asPropList!.behavior.notify(["jump": part]) -- stub
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
