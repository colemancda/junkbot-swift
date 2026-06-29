// Translated from Lingo: parent_hazard slick fire parent.ls

class HazardSlickFireParent {
    var playfield_manager: Any? = nil
    var play_manager: PlayManager? = nil
    var part: [String: Any]
    var myWidth: Int = 2
    var last_step: Int = 0
    var dir: Any? = nil

    init(_ p: [String: Any]) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
        myWidth = 2
        last_step = Int(Date().timeIntervalSince1970 * 60)
    }

    func done() {
        play_manager?.actorDone(self)
    }

    func notify(_ notes: [String: Any]) {
        if let destroyed = notes["destroyed"] as? Int, destroyed == 1 {
            done()
        } else if notes["pos"] != nil {
            part["pos"] = notes["pos"]!
        } else if let sw = notes["switch"] {
            part["state"] = sw
            stepAnim()
            updatePart()
        }
    }

    func stepFrame() {
        stepAnim()
        updatePart()
        let state = part["state"] as? String ?? ""
        if state == "#on" {
            checkMiniFig()
        }
    }

    func updatePart() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // playfield_manager.placePiece(part) -- stub
    }

    func stepAnim() {
        let state = part["state"] as? String ?? ""
        if state == "#on" {
            if let frame = part["frame"] as? Int {
                part["frame"] = (frame % 7) + 1
            }
        } else {
            part["frame"] = 1
        }
    }

    func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_02") -- stub
        let fig: Any? = nil // stub
        if let figDict = fig as? [String: Any] {
            SndSFX("fire")
            // figDict.behavior.notify(["damage": "#fire"]) -- stub
            _ = figDict
        }
    }
}
