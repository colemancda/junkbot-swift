// Translated from Lingo: parent_hazard float parent.ls

public class HazardFloatParent: LingoObject, @unchecked Sendable {
    public var part: PropList
    public var play_manager: PlayManager? = nil
    public var playfield_manager: PlayfieldManager? = nil
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
    //   pDir = [1, 0]
    //   pSpeed = 2
    //   pCounter = 0
    //   pTarget = 0
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   return me
    // end
    // ```
    public init(_ p: PropList) {        part = p

        super.init()
        pDir = [1, 0]
        pSpeed = 2
        pCounter = 0
        pTarget = 0
        play_manager = Glob.shared["PLAYER"].asObject()?.asPlayManager ?? Glob.shared["PLAYER"].asPropList?["play_manager"].asPlayManager
        playfield_manager = play_manager?.playfield_manager
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
    //   if pTarget then
    //     part.state = #Active
    //   else
    //     part.state = #inactive
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
    //   x = pos[1]
    //   y = pos[2]
    //   repeat with r = x to mW
    //     myObj = playfield_manager.getPart(point(r, y))
    //     if voidp(myObj) then
    //       next repeat
    //     end if
    //     myPartType = myObj[#type]
    //     if not (myPartType = #MINIFIG) then
    //       exit repeat
    //       next repeat
    //     end if
    //     if myPartType = #MINIFIG then
    //       pTarget = 1
    //       pTimer = the timer
    //       pDir = [1, 0]
    //       SndSFX("siren")
    //       flag = VOID
    //     end if
    //   end repeat
    //   repeat with r = x down to 1
    //     myObj = playfield_manager.getPart(point(r, y))
    //     if voidp(myObj) then
    //       next repeat
    //     end if
    //     myPartType = myObj[#type]
    //     if not (myPartType = #MINIFIG) then
    //       exit repeat
    //       next repeat
    //     end if
    //     if myPartType = #MINIFIG then
    //       pTarget = 1
    //       pTimer = the timer
    //       pDir = [-1, 0]
    //       SndSFX("siren")
    //       flag = VOID
    //     end if
    //   end repeat
    //   repeat with c = y to mH
    //     myObj = playfield_manager.getPart(point(x, c))
    //     if voidp(myObj) then
    //       next repeat
    //     end if
    //     myPartType = myObj[#type]
    //     if not (myPartType = #MINIFIG) then
    //       exit repeat
    //       next repeat
    //     end if
    //     if myPartType = #MINIFIG then
    //       pTarget = 1
    //       pTimer = the timer
    //       pDir = [0, 1]
    //       SndSFX("siren")
    //       flag = VOID
    //     end if
    //   end repeat
    //   repeat with c = y down to 1
    //     myObj = playfield_manager.getPart(point(x, c))
    //     if voidp(myObj) then
    //       next repeat
    //     end if
    //     myPartType = myObj[#type]
    //     if not (myPartType = #MINIFIG) then
    //       exit repeat
    //       next repeat
    //     end if
    //     if myPartType = #MINIFIG then
    //       pTarget = 1
    //       pTimer = the timer
    //       pDir = [0, -1]
    //       SndSFX("siren")
    //       flag = VOID
    //     end if
    //   end repeat
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
        if pTarget != 0 {
            part["state"] = .string("#Active")
        } else {
            part["state"] = .string("#inactive")
        }
        let frame = part["frame"].asInt ?? 1
        part["frame"] = .int(frame == 1 ? 2 : 1)
        playfield_manager?.erasePiece(part["pos"] ?? .void)
        let _pos = (part["pos"].asPoint ?? Point()) + Point(x: pDir[0], y: pDir[1])
        var fg = playfield_manager?.checkFitMiniFigHit(LV.pt(_pos.x, _pos.y), part["type"].asString ?? "") ?? false
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
            Glob.shared["minifigHit"].asPropList?["behavior"].asObject()?.notify(PropList([("damage", .string("#floater"))]))
        }

        if flag == "#TURN" {
            pDir = pDir.map { -$0 }
        } else {
            let _pLoc = (pLoc.asPoint ?? Point()) + Point(x: pDir[0], y: pDir[1])
            pLoc = LV.pt(_pLoc.x, _pLoc.y)
        }
        playfield_manager?.placePiece(part)
        _ = mW; _ = mH; _ = pos_x; _ = pos_y
    }
}
