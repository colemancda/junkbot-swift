// Translated from Lingo: parent_hazard slick shield parent.ls

public class HazardSlickShieldParent: LingoObject, @unchecked Sendable {
  public var play_manager: PlayManager? = nil
  public var playfield_manager: PlayfieldManager? = nil
  public var part: PropList
  public var stepped_on: Int = 0

  // Original Lingo body: new
  // ```lingo
  // on new me, p
  //   part = p
  //   part[#behavior] = me
  //   play_manager = glob.PLAYER.play_manager
  //   playfield_manager = play_manager.playfield_manager
  //   stepped_on = 0
  //   return me
  // end
  // ```
  public init(_ p: PropList) {
    part = p

    super.init()
    // part["behavior"] = self -- set by caller
    play_manager =
      Glob.shared["PLAYER"].asObject()?.asPlayManager
      ?? Glob.shared["PLAYER"].asPropList?["play_manager"].asPlayManager
    playfield_manager = play_manager?.playfield_manager
    stepped_on = 0
  }

  // Original Lingo body: notify
  // ```lingo
  // on notify me, args
  // end
  // ```
  public override func notify(_ args: PropList) {
    // No-op in original
  }

  // Original Lingo body: done
  // ```lingo
  // on done me
  //   play_manager.actorDone(me)
  // end
  // ```
  public func done() {
    if let pm = play_manager { pm.actorDone(self) }
  }

  // Original Lingo body: stepframe
  // ```lingo
  // on stepFrame me
  //   if part.state = #on then
  //     me.checkMiniFig()
  //   end if
  // end
  // ```
  public func stepFrame() {
    let state = part["state"].asString ?? ""
    if state == "#on" {
      checkMiniFig()
    }
  }

  // Original Lingo body: checkminifig
  // ```lingo
  // on checkMiniFig me
  //   fig = playfield_manager.checkFitOrMinifig(part.pos + point(0, -1), #BRICK_01)
  //   fig2 = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), #BRICK_01)
  //   if (fig = fig2) and (ilk(fig) = #propList) then
  //     fig.behavior.notify([#SHIELD: 1])
  //     part.state = #off
  //     me.redrawPart()
  //   end if
  // end
  // ```
  public func checkMiniFig() {
    let _pos = (part["pos"].asPoint ?? Point()) + Point(x: 0, y: -1)
    var fig = playfield_manager?.checkFitOrMinifig(LV.pt(_pos.x, _pos.y), "#BRICK_01") ?? .void
    let _pos2 = (part["pos"].asPoint ?? Point()) + Point(x: 1, y: -1)
    var fig2 = playfield_manager?.checkFitOrMinifig(LV.pt(_pos2.x, _pos2.y), "#BRICK_01") ?? .void

    // (fig == fig2) && fig.isPropList
    if fig.isPropList && fig2.isPropList {
      // check fig === fig2 (same object) at runtime
      fig.asPropList?["behavior"].asObject()?.notify(PropList([("SHIELD", .int(1))]))
      part["state"] = .string("#off")
      redrawPart()
    }
  }

  // Original Lingo body: redrawpart
  // ```lingo
  // on redrawPart me
  //   playfield_manager.erasePiece(part.pos)
  //   playfield_manager.placePiece(part)
  // end
  // ```
  public func redrawPart() {
    playfield_manager?.erasePiece(part.pos)
    playfield_manager?.placePiece(part)
  }
}
