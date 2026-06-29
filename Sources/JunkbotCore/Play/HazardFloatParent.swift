// Translated from Lingo: parent_hazard float parent.ls

class HazardFloatParent {
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
        pDir = [1, 0]
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
        if pTarget != 0 {
            part["state"] = "#Active"
        } else {
            part["state"] = "#inactive"
        }
        if let frame = part["frame"] as? Int {
            part["frame"] = frame == 1 ? 2 : 1
        }
        // playfield_manager.erasePiece(part.pos) -- stub
        // pos = part.pos + pDir -- stub
        // fg = playfield_manager.checkFitMiniFigHit(pos, part.type) -- stub
        var flag: String? = nil
        // ok = fg; if !ok { flag = "#TURN" } else { part.pos = pos }

        // stub: boundary check using pf_size
        // if pos out of bounds { flag = "#TURN"; pos = part.pos }
        // else if getPart(pos) != nil { flag = "#TURN"; pos = part.pos }

        let pos_x = 0 // stub
        let pos_y = 0 // stub
        // stub: mW, mH from playfield_manager.pf_size
        let mW = 0 // stub
        let mH = 0 // stub

        // Scan row right for minifig
        for r in pos_x...max(pos_x, mW) {
            // myObj = playfield_manager.getPart(point(r, pos_y)) -- stub
            let myObj: [String: Any]? = nil // stub
            guard let obj = myObj else { continue }
            let myPartType = obj["type"] as? String ?? ""
            if myPartType != "#MINIFIG" { break }
            if myPartType == "#MINIFIG" {
                pTarget = 1
                pTimer = Int(Date().timeIntervalSince1970 * 60)
                pDir = [1, 0]
                SndSFX("siren")
                flag = nil
            }
            _ = r
        }

        // Scan row left for minifig
        for r in stride(from: pos_x, through: 1, by: -1) {
            let myObj: [String: Any]? = nil // stub
            guard let obj = myObj else { continue }
            let myPartType = obj["type"] as? String ?? ""
            if myPartType != "#MINIFIG" { break }
            if myPartType == "#MINIFIG" {
                pTarget = 1
                pTimer = Int(Date().timeIntervalSince1970 * 60)
                pDir = [-1, 0]
                SndSFX("siren")
                flag = nil
            }
            _ = r
        }

        // Scan column down for minifig
        for c in pos_y...max(pos_y, mH) {
            let myObj: [String: Any]? = nil // stub
            guard let obj = myObj else { continue }
            let myPartType = obj["type"] as? String ?? ""
            if myPartType != "#MINIFIG" { break }
            if myPartType == "#MINIFIG" {
                pTarget = 1
                pTimer = Int(Date().timeIntervalSince1970 * 60)
                pDir = [0, 1]
                SndSFX("siren")
                flag = nil
            }
            _ = c
        }

        // Scan column up for minifig
        for c in stride(from: pos_y, through: 1, by: -1) {
            let myObj: [String: Any]? = nil // stub
            guard let obj = myObj else { continue }
            let myPartType = obj["type"] as? String ?? ""
            if myPartType != "#MINIFIG" { break }
            if myPartType == "#MINIFIG" {
                pTarget = 1
                pTimer = Int(Date().timeIntervalSince1970 * 60)
                pDir = [0, -1]
                SndSFX("siren")
                flag = nil
            }
            _ = c
        }

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
        _ = mW; _ = mH; _ = pos_x; _ = pos_y
    }
}
