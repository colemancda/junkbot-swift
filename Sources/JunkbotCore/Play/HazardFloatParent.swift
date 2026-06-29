// Translated from Lingo: parent_hazard float parent.ls

public class HazardFloatParent {
    public var part: PropList
    public var play_manager: PlayManager? = nil
    public var playfield_manager: LV = .void
    public var pLoc: LV = .void
    public var pBaseLoc: LV = .void
    public var pDir: [Int] = [1, 0]
    public var pSpeed: Int = 2
    public var pCounter: Int = 0
    public var pLocZ: LV = .void
    public var pTarget: Int = 0
    public var pTimer: Int = 0

    public init(_ p: PropList) {
        part = p
        pDir = [1, 0]
        pSpeed = 2
        pCounter = 0
        pTarget = 0
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
    }

    public func stepFrame() {
        pCounter = (pCounter + 1) % pSpeed
        if pCounter == 0 {
            moveMe()
        }
        let timer = currentTicks
        if pTarget != 0 && (timer > (pTimer + 120)) {
            pTarget = 0
        }
    }

    public func stepAnim() {
        let frame = part["frame"].asInt ?? 1
        part["frame"] = .int((frame % 2) + 1)
    }

    public func moveMe() {
        Glob.shared["minifigHit"] = .void
        if pTarget != 0 {
            part["state"] = .string("#Active")
        } else {
            part["state"] = .string("#inactive")
        }
        let frame = part["frame"].asInt ?? 1
        part["frame"] = .int(frame == 1 ? 2 : 1)
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
        let mW = 0 // stub: playfield_manager.pf_size width
        let mH = 0 // stub: playfield_manager.pf_size height

        // Scan row right for minifig
        for r in pos_x...max(pos_x, mW) {
            // myObj = playfield_manager.getPart(point(r, pos_y)) -- stub
            let myObj: PropList? = nil // stub
            guard let obj = myObj else { continue }
            let myPartType = obj["type"].asString ?? ""
            if myPartType != "#MINIFIG" { break }
            if myPartType == "#MINIFIG" {
                pTarget = 1
                pTimer = currentTicks
                pDir = [1, 0]
                SndSFX("siren")
                flag = nil
            }
            _ = r
        }

        // Scan row left for minifig
        for r in stride(from: pos_x, through: 1, by: -1) {
            let myObj: PropList? = nil // stub
            guard let obj = myObj else { continue }
            let myPartType = obj["type"].asString ?? ""
            if myPartType != "#MINIFIG" { break }
            if myPartType == "#MINIFIG" {
                pTarget = 1
                pTimer = currentTicks
                pDir = [-1, 0]
                SndSFX("siren")
                flag = nil
            }
            _ = r
        }

        // Scan column down for minifig
        for c in pos_y...max(pos_y, mH) {
            let myObj: PropList? = nil // stub
            guard let obj = myObj else { continue }
            let myPartType = obj["type"].asString ?? ""
            if myPartType != "#MINIFIG" { break }
            if myPartType == "#MINIFIG" {
                pTarget = 1
                pTimer = currentTicks
                pDir = [0, 1]
                SndSFX("siren")
                flag = nil
            }
            _ = c
        }

        // Scan column up for minifig
        for c in stride(from: pos_y, through: 1, by: -1) {
            let myObj: PropList? = nil // stub
            guard let obj = myObj else { continue }
            let myPartType = obj["type"].asString ?? ""
            if myPartType != "#MINIFIG" { break }
            if myPartType == "#MINIFIG" {
                pTarget = 1
                pTimer = currentTicks
                pDir = [0, -1]
                SndSFX("siren")
                flag = nil
            }
            _ = c
        }

        if !Glob.shared["minifigHit"].isVoid {
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
