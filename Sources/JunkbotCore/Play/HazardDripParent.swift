// Translated from Lingo: parent_hazard drip parent.ls

class HazardDripParent {
    var playfield_manager: Any? = nil
    var play_manager: PlayManager? = nil
    var part: [String: Any]
    var pipe: HazardSlickPipeParent? = nil
    var s: Any? = nil
    var driploc: Point = Point(x: 0, y: 0)
    var dripstate: Any = "#falling" // either "#falling" or an Int (splash frame counter)
    var top_locz: Any? = nil

    init(_ mypipe: HazardSlickPipeParent, _ mypart: [String: Any]) {
        pipe = mypipe
        part = mypart
        dripstate = "#falling"
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
        // top_locz = playfield_manager.posToLocZ(point(50, 1)) -- stub
        // driploc = playfield_manager.getLoc(part.pos) + point(0, 17) -- stub
        let partPos = mypart["pos"] as? Point ?? Point(x: 0, y: 0)
        _ = partPos
    }

    func done() {
        pipe?.dripDone(self)
    }

    func stepFrame() {
        // s = playfield_manager.getASprite() -- stub
        // part.auxSprites["myDrip"] = s -- stub
        // s.ink = 8 -- stub
        // s.visible = 1 -- stub

        if let ds = dripstate as? String, ds == "#falling" {
            let newloc = Point(x: driploc.x, y: driploc.y + 18)
            // posloc = playfield_manager.getPos(newloc) -- stub
            let posloc: Any? = nil // stub
            var fit: Any = 0
            if posloc == nil {
                fit = 0
            } else {
                // fit = playfield_manager.checkFitOrMinifig(posloc[1], "#BRICK_02") -- stub
                fit = 1 // stub
            }
            if let fitInt = fit as? Int, fitInt == 1 {
                driploc = newloc
            } else {
                dripstate = 1
                if let fitDict = fit as? [String: Any] {
                    // fitDict.behavior.notify(["damage": "#drip"]) -- stub
                    SndSFX("electricity1")
                    _ = fitDict
                } else {
                    SndSFX("drip\(Int.random(in: 1...3))")
                }
            }
            // s.member = member("drip_falling_1") -- stub
            // s.rect = s.member.rect -- stub
        } else {
            let ds = dripstate as? Int ?? 1
            // s.member = member("drip_splashing_\(ds)") -- stub
            // s.rect = s.member.rect -- stub
            dripstate = ds + 1
            if let newDs = dripstate as? Int, newDs > 5 {
                done()
            }
        }
        // s.loc = driploc -- stub
        // s.locZ = top_locz -- stub
    }
}
