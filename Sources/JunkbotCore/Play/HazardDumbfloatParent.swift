// Translated from Lingo: parent_hazard dumbfloat parent.ls

public class HazardDumbfloatParent {
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
        let state = p["state"].asString ?? ""
        if state == "#L" {
            pDir = [-1, 0]
        } else {
            pDir = [1, 0]
        }
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
        if pDir[0] < 0 {
            part["state"] = .string("#L")
        } else {
            part["state"] = .string("#r")
        }
        let frame = part["frame"].asInt ?? 1
        part["frame"] = .int(frame == 1 ? 2 : 1)
        // playfield_manager.erasePiece(part.pos) -- stub
        // pos = part.pos + pDir -- stub
        // fg = playfield_manager.checkFitMiniFigHit(pos, part.type) -- stub
        var flag: String? = nil
        // ok = fg; if !ok { flag = "#TURN" } else { part.pos = pos }

        // stub: boundary check
        // if pos out of bounds { flag = "#TURN"; pos = part.pos }
        // else if getPart(pos) != nil { flag = "#TURN"; pos = part.pos }

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
    }
}
