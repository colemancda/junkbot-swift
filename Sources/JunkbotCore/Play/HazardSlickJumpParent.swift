// Translated from Lingo: parent_hazard slick jump parent.ls

class HazardSlickJumpParent {
    var playfield_manager: Any? = nil
    var play_manager: PlayManager? = nil
    var part: [String: Any]
    var last_jump: Int = 0
    var active_ticks: Any? = nil
    var dir: Any? = nil
    var paused: Int = 0

    init(_ p: [String: Any]) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
        last_jump = 0
    }

    func done() {
        play_manager?.actorDone(self)
    }

    func pause() {
        paused = 1
    }

    func resume() {
        paused = 0
        part["state"] = "#dormant"
        part["frame"] = 1
    }

    func notify(_ notes: [String: Any]) {
        if let destroyed = notes["destroyed"] as? Int, destroyed == 1 {
            done()
        } else if notes["pos"] != nil {
            part["pos"] = notes["pos"]!
        } else if let stop = notes["stop"] as? Int, stop == 1 {
            pause()
        } else if let start = notes["Start"] as? Int, start == 1 {
            resume()
        }
    }

    func stepFrame() {
        if paused == 1 { return }
        // playfield_manager.erasePiece(part.pos) -- stub
        stepAnim()
        checkMiniFig()
        // playfield_manager.placePiece(part) -- stub
    }

    func stepAnim() {
        // No animation logic in original
    }

    func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(0, -1), "#BRICK_01") -- stub
        let fig: Any? = nil // stub
        // fig2 = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_01") -- stub
        let fig2: Any? = nil // stub
        let ticks = Int(Date().timeIntervalSince1970 * 60)

        let figIsDict = fig is [String: Any]
        let fig2IsDict = fig2 is [String: Any]
        // Check: (fig == fig2) && ilk(fig) == #propList && (ticks - last_jump) > 60
        // Since both are stubs (nil), guard will fail; shown for structure fidelity
        if figIsDict && fig2IsDict && (ticks - last_jump) > 60 {
            if let figDict = fig as? [String: Any], let fig2Dict = fig2 as? [String: Any] {
                // check fig === fig2 (same object)
                _ = figDict; _ = fig2Dict
                SndSFX("jump3")
                // fig.behavior.notify(["jump": part]) -- stub
                part["state"] = "#Active"
                part["frame"] = 1
                last_jump = ticks
            }
        } else {
            let state = part["state"] as? String ?? ""
            if state == "#Active" {
                let frame = (part["frame"] as? Int ?? 0) + 1
                if frame > 4 {
                    part["frame"] = 1
                    part["state"] = "#dormant"
                } else {
                    part["frame"] = frame
                }
            }
        }
    }
}
