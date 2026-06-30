// Translated from Lingo: parent_hazard dumbfloat parent.ls

public class HazardDumbfloatParent: LingoObject, @unchecked Sendable {
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

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   if part.state = #L then
    //     pDir = [-1, 0]
    //   else
    //     pDir = [1, 0]
    //   end if
    //   pSpeed = 2
    //   pCounter = 0
    //   pTarget = 0
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   return me
    // end
    // ```
    public init(_ p: PropList) {
        super.init()
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

    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   pCounter = (pCounter + 1) mod pSpeed
    //   if pCounter = 0 then
    //     moveMe(me)
    //   end if
    //   if pTarget and (the timer > (pTimer + 120)) then
    //     pTarget = 0
    //   end if
    // end
    // ```
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

    // Original Lingo body: stepanim
    // ```lingo
    // on stepAnim me
    //   part.frame = (part.frame mod 2) + 1
    // end
    // ```
    public func stepAnim() {
        let frame = part["frame"].asInt ?? 1
        part["frame"] = .int((frame % 2) + 1)
    }

    // Original Lingo body: moveme
    // ```lingo
    // on moveMe me
    //   glob.PLAYER[#minifigHit] = VOID
    //   if pDir[1] < 0 then
    //     part.state = #L
    //   else
    //     part.state = #r
    //   end if
    //   if part.frame = 1 then
    //     part.frame = 2
    //   else
    //     part.frame = 1
    //   end if
    //   playfield_manager.erasePiece(part.pos)
    //   pos = part.pos + pDir
    //   fg = playfield_manager.checkFitMiniFigHit(pos, part.type)
    //   Ok = fg
    //   if not Ok then
    //     flag = #TURN
    //   else
    //     part.pos = pos
    //   end if
    //   mW = playfield_manager.pf_size[1]
    //   mH = playfield_manager.pf_size[2]
    //   if (pos[1] > mW) or (pos[1] < 1) or (pos[2] > mH) or (pos[2] < 1) then
    //     flag = #TURN
    //     pos = part.pos
    //   else
    //     if not voidp(playfield_manager.getPart(pos)) then
    //       flag = #TURN
    //       pos = part.pos
    //     end if
    //   end if
    //   if not voidp(glob.PLAYER[#minifigHit]) then
    //     SndSFX("robottouch4")
    //     glob.PLAYER.minifigHit.behavior.notify([#damage: #floater])
    //   end if
    //   if flag = #TURN then
    //     pDir = -pDir
    //   else
    //     pLoc = pLoc + pDir
    //   end if
    //   playfield_manager.placePiece(part)
    // end
    // ```
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
