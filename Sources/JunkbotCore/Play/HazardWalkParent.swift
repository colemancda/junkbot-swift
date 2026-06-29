// Translated from Lingo: parent_hazard walk parent.ls

class HazardWalkParent {
    var playfield_manager: Any? = nil
    var play_manager: PlayManager? = nil
    var part: [String: Any]
    var myWidth: Int = 2
    var speed: Int = 4
    var last_step: Int = 0
    var dir: Int = 1

    init(_ p: [String: Any]) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
        myWidth = 2
        let state = p["state"] as? String ?? ""
        if state == "WALK_L" {
            dir = -1
        } else {
            dir = 1
        }
        speed = 4
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
        }
    }

    func step() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // pos = part.pos + point(dir, 0) -- stub
        var ok = false
        // fg = playfield_manager.checkFitOrMinifig(pos, part.type) -- stub
        let fg: Any? = nil // stub
        _ = fg

        // if fg == 1 { if playfield_manager.checkFloor(pos, myWidth) > 1 { ok = true; part.pos = pos } }
        if !ok {
            dir = -dir
            if dir > 0 {
                part["state"] = "#WALK_R"
            } else {
                part["state"] = "#walk_l"
            }
        }
        // if ilk(fg) = #propList { SndSFX("robottouch4"); fg.behavior.notify(["damage": "#walker"]) } -- stub
        // playfield_manager.placePiece(part) -- stub
    }

    func stepAnim() {
        if let frame = part["frame"] as? Int {
            if frame == 1 {
                part["frame"] = 2
            } else {
                part["frame"] = 1
            }
        }
    }

    func stepFrame() {
        if let frame = part["frame"] as? Int, frame == 2 {
            step()
        }
        // playfield_manager.erasePiece(part.pos) -- stub
        stepAnim()
        // playfield_manager.placePiece(part) -- stub
    }
}
