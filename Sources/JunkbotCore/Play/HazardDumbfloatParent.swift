// Translated from Lingo: parent_hazard dumbfloat parent.ls

public class HazardDumbfloatParent: LingoObject, @unchecked Sendable {
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
    part = p

    super.init()
    let state = p["state"].asString ?? ""
    if state == "#L" {
      pDir = [-1, 0]
    } else {
      pDir = [1, 0]
    }
    pSpeed = 2
    pCounter = 0
    pTarget = 0
    play_manager =
      Glob.shared["PLAYER"].asObject()?.asPlayManager
      ?? Glob.shared["PLAYER"].asPropList?["play_manager"].asPlayManager
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
    playfield_manager?.erasePiece(part["pos"] ?? .void)
    let origPos = part["pos"].asPoint ?? Point()
    var pos = origPos + Point(x: pDir[0], y: pDir[1])
    var fg =
      playfield_manager?.checkFitMiniFigHit(LV.pt(pos.x, pos.y), part["type"].asString ?? "")
      ?? false
    var flag: String? = nil
    var ok = fg
    if !ok {
      flag = "#TURN"
    } else {
      part["pos"] = LV.pt(pos.x, pos.y)
    }

    let pf_size = playfield_manager?.pf_size.asPoint ?? Point(x: 20, y: 15)
    let mW = pf_size.x
    let mH = pf_size.y

    if pos.x > mW || pos.x < 1 || pos.y > mH || pos.y < 1 {
      flag = "#TURN"
      pos = origPos
    } else {
      let cell = playfield_manager?.getPart(LV.pt(pos.x, pos.y))
      if cell != nil {
        flag = "#TURN"
        pos = origPos
      }
    }

    if !Glob.shared["minifigHit"].isVoid {
      SndSFX("robottouch4")
      Glob.shared["minifigHit"].asPropList?["behavior"].asObject()?.notify(
        PropList([("damage", .string("#floater"))]))
    }

    if flag == "#TURN" {
      pDir = pDir.map { -$0 }
    } else {
      let _pLoc = (pLoc.asPoint ?? Point()) + Point(x: pDir[0], y: pDir[1])
      pLoc = LV.pt(_pLoc.x, _pLoc.y)
    }
    playfield_manager?.placePiece(part)
  }
}
