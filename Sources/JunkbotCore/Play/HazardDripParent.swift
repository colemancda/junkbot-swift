// Translated from Lingo: parent_hazard drip parent.ls

public enum DripState {
    case falling
    case splashing(Int)
}

public class HazardDripParent {
    public var playfield_manager: LV = .void
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var pipe: HazardSlickPipeParent? = nil
    public var s: LV = .void
    public var driploc: Point = Point()
    public var dripstate: DripState = .falling
    public var top_locz: LV = .void

    public init(_ mypipe: HazardSlickPipeParent, _ mypart: PropList) {
        pipe = mypipe
        part = mypart
        dripstate = .falling
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        // top_locz = playfield_manager.posToLocZ(point(50, 1)) -- stub
        // driploc = playfield_manager.getLoc(part.pos) + point(0, 17) -- stub
        let partPos = mypart["pos"].asPoint ?? Point()
        _ = partPos
    }

    public func done() {
        pipe?.dripDone(self)
    }

    public func stepFrame() {
        // s = playfield_manager.getASprite() -- stub
        // part.auxSprites["myDrip"] = s -- stub
        // s.ink = 8 -- stub
        // s.visible = 1 -- stub

        switch dripstate {
        case .falling:
            let newloc = Point(x: driploc.x, y: driploc.y + 18)
            // posloc = playfield_manager.getPos(newloc) -- stub
            let posloc: LV = .void // stub
            var fit: LV = .int(0)
            if posloc.isVoid {
                fit = .int(0)
            } else {
                // fit = playfield_manager.checkFitOrMinifig(posloc, "#BRICK_02") -- stub
                fit = .int(1) // stub
            }
            if let fitInt = fit.asInt, fitInt == 1 {
                driploc = newloc
            } else {
                dripstate = .splashing(1)
                if fit.isPropList {
                    // fit.asPropList!.behavior.notify(["damage": "#drip"]) -- stub
                    SndSFX("electricity1")
                } else {
                    SndSFX("drip\(lingoRandom(3))")
                }
            }
            // s.member = member("drip_falling_1") -- stub
            // s.rect = s.member.rect -- stub
        case .splashing(let ds):
            // s.member = member("drip_splashing_\(ds)") -- stub
            // s.rect = s.member.rect -- stub
            let next = ds + 1
            if next > 5 {
                done()
            } else {
                dripstate = .splashing(next)
            }
        }
        // s.loc = driploc -- stub
        // s.locZ = top_locz -- stub
    }
}
