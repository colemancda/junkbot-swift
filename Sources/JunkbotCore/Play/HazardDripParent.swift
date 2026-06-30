// Translated from Lingo: parent_hazard drip parent.ls

public enum DripState {
  case falling
  case splashing(Int)
}

public class HazardDripParent: LingoObject, @unchecked Sendable {
  public var playfield_manager: PlayfieldManager? = nil
  public var play_manager: PlayManager? = nil
  public var part: PropList
  public var pipe: HazardSlickPipeParent? = nil
  public var s: LV = .void
  public var driploc: Point = Point()
  public var dripstate: DripState = .falling
  public var top_locz: LV = .void

  // Original Lingo body: new
  // ```lingo
  // on new me, mypipe, mypart
  //   pipe = mypipe
  //   part = mypart
  //   dripstate = #falling
  //   play_manager = glob.PLAYER.play_manager
  //   playfield_manager = play_manager.playfield_manager
  //   top_locz = playfield_manager.posToLocZ(point(50, 1))
  //   driploc = playfield_manager.getLoc(part.pos) + point(0, 17)
  //   return me
  // end
  // ```
  public init(_ mypipe: HazardSlickPipeParent, _ mypart: PropList) {
    pipe = mypipe
    part = mypart

    super.init()
    dripstate = .falling
    play_manager =
      Glob.shared["PLAYER"].asObject()?.asPlayManager
      ?? Glob.shared["PLAYER"].asPropList?["play_manager"].asPlayManager
    playfield_manager = play_manager?.playfield_manager
    if let pm = playfield_manager {
      top_locz = .int(pm.posToLocZ(Point(x: 50, y: 1)))
      driploc = pm.getLoc(mypart["pos"]) + Point(x: 0, y: 17)
    }
  }

  // Original Lingo body: done
  // ```lingo
  // on done me
  //   pipe.dripDone(me)
  // end
  // ```
  public func done() {
    pipe?.dripDone(self)
  }

  // Original Lingo body: stepframe
  // ```lingo
  // on stepFrame me
  //   s = playfield_manager.getASprite()
  //   part.auxSprites[#myDrip] = s
  //   s.ink = 8
  //   s.visible = 1
  //   if dripstate = #falling then
  //     newloc = driploc + point(0, 18)
  //     posloc = playfield_manager.getPos(newloc)
  //     if voidp(posloc) then
  //       fit = 0
  //     else
  //       fit = playfield_manager.checkFitOrMinifig(posloc[1], #BRICK_02)
  //     end if
  //     if fit = 1 then
  //       driploc = newloc
  //     else
  //       dripstate = 1
  //       if ilk(fit) = #propList then
  //         fit.behavior.notify([#damage: #drip])
  //         SndSFX("electricity1")
  //       else
  //         SndSFX("drip" & random(3))
  //       end if
  //     end if
  //     s.member = member("drip_falling_1")
  //     s.rect = s.member.rect
  //   else
  //     s.member = member("drip_splashing_" & dripstate)
  //     s.rect = s.member.rect
  //     dripstate = dripstate + 1
  //     if dripstate > 5 then
  //       me.done()
  //     end if
  //   end if
  //   s.loc = driploc
  //   s.locZ = top_locz
  // end
  // ```
  public func stepFrame() {

    switch dripstate {
    case .falling:
      let newloc = Point(x: driploc.x, y: driploc.y + 18)
      let arr = playfield_manager?.getPos(newloc)
      let posloc: LV = arr != nil ? .list(LingoList(arr!)) : .void
      var fit: LV = .int(0)
      if posloc.isVoid {
        fit = .int(0)
      } else {
        fit = playfield_manager?.checkFitOrMinifig(posloc, "#BRICK_02") ?? .int(0)
      }
      if let fitInt = fit.asInt, fitInt == 1 {
        driploc = newloc
      } else {
        dripstate = .splashing(1)
        if fit.isPropList {
          fit.asPropList?["behavior"].asObject()?.notify(PropList([("damage", .string("#drip"))]))
          SndSFX("electricity1")
        } else {
          SndSFX("drip\(lingoRandom(3))")
        }
      }
    case .splashing(let ds):
      let next = ds + 1
      if next > 5 {
        done()
      } else {
        dripstate = .splashing(next)
      }
    }
  }
}
