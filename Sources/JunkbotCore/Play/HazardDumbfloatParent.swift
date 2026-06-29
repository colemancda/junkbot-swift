// Translated from Lingo: parent_hazard dumbfloat parent.ls

class HazardDumbfloatParent {
    var part: [String: Any]
    var play_manager: PlayManager? = nil
    var playfield_manager: Any? = nil
    var pLoc: Any? = nil
    var pBaseLoc: Any? = nil
    var pDir: [Int] = [1, 0]
    var pSpeed: Int = 2
    var pCounter: Int = 0
    var pLocZ: Any? = nil
    var pTarget: Int = 0
    var pTimer: Int = 0

    init(_ p: [String: Any]) {
        part = p
        let state = p["state"] as? String ?? ""
        if state == "#L" {
            pDir = [-1, 0]
        } else {
            pDir = [1, 0]
        }
        pSpeed = 2
        pCounter = 0
        pTarget = 0
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
    }

    func stepFrame() {
        pCounter = (pCounter + 1) % pSpeed
        if pCounter == 0 {
            moveMe()
        }
        let timer = Int(Date().timeIntervalSince1970 * 60) // stub: the timer
        if pTarget != 0 && (timer > (pTimer + 120)) {
            pTarget = 0
        }
    }

    func stepAnim() {
        if let frame = part["frame"] as? Int {
            part["frame"] = (frame % 2) + 1
        }
    }

    func moveMe() {
        Glob.shared["minifigHit"] = nil
        if pDir[0] < 0 {
            part["state"] = "#L"
        } else {
            part["state"] = "#r"
        }
        if let frame = part["frame"] as? Int {
            part["frame"] = frame == 1 ? 2 : 1
        }
        // playfield_manager.erasePiece(part.pos) -- stub
        // pos = part.pos + pDir -- stub
        // fg = playfield_manager.checkFitMiniFigHit(pos, part.type) -- stub
        var flag: String? = nil
        // ok = fg; if !ok { flag = "#TURN" } else { part.pos = pos }

        // stub: boundary check
        // if pos out of bounds { flag = "#TURN"; pos = part.pos }
        // else if getPart(pos) != nil { flag = "#TURN"; pos = part.pos }

        if Glob.shared["minifigHit"] != nil {
            SndSFX("robottouch4")
            // Glob.shared.minifigHit.behavior.notify(["damage": "#floater"]) -- stub
        }

        if flag == "#TURN" {
            pDir = pDir.map { -$0 }
        } else {
            // pLoc = pLoc + pDir -- stub
        }
        // playfield_manager.placePiece(part) -- stub
    }
}
