// Translated from Lingo: parent_hazard slick fan parent.ls

class HazardSlickFanParent {
    var playfield_manager: Any? = nil
    var play_manager: PlayManager? = nil
    var part: [String: Any]
    var myWidth: Int = 2
    var last_step: Int = 0
    var switch_: Int = 0  // 'switch' is a Swift keyword, renamed to switch_
    var airjet_cycle: Int = 1
    var partloc: Point = Point(x: 0, y: 0)
    var top_locz: Any? = nil
    var dir: Any? = nil

    init(_ p: [String: Any]) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
        // partloc = part.sprite[1].loc -- stub
        myWidth = 2
        last_step = Int(Date().timeIntervalSince1970 * 60)
        switch_ = 0
        airjet_cycle = Int.random(in: 1...7)
        // top_locz = playfield_manager.posToLocZ(point(50, 1)) -- stub
    }

    func done() {
        play_manager?.actorDone(self)
    }

    func notify(_ notes: [String: Any]) {
        if let destroyed = notes["destroyed"] as? Int, destroyed == 1 {
            done()
        } else if notes["pos"] != nil {
            part["pos"] = notes["pos"]!
        } else if let sw = notes["switch"] {
            part["state"] = sw
            stepAnim()
            updatePart()
        }
    }

    func stepFrame() {
        stepAnim()
        updatePart()
        checkMiniFig()
    }

    func stepAnim() {
        let state = part["state"] as? String ?? ""
        if state == "#on" {
            if let frame = part["frame"] as? Int {
                part["frame"] = (frame % 4) + 1
            }
        } else {
            part["frame"] = 1
        }
    }

    func checkMiniFig() {
        let state = part["state"] as? String ?? ""
        var gotMinifig: Any? = nil
        var airjet_height = [0, 0]
        if state == "#on" {
            var y = -1
            while true {
                // fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, y), "#BRICK_01") -- stub
                let fig: Any = 1 // stub
                let figInt = fig as? Int
                if figInt == 0 { break }
                if figInt == nil {
                    gotMinifig = fig
                    break
                }
                y -= 1
                airjet_height[0] += 1
            }
            y = -1
            while true {
                // fig = playfield_manager.checkFitOrMinifig(part.pos + point(2, y), "#BRICK_01") -- stub
                let fig: Any = 1 // stub
                let figInt = fig as? Int
                if figInt == 0 { break }
                if figInt == nil {
                    gotMinifig = fig
                    break
                }
                y -= 1
                airjet_height[1] += 1
            }
            if let gm = gotMinifig, !(gm is Int) || (gm as? Int) != 0 {
                if switch_ == 0 {
                    SndSFX("fan")
                    switch_ = 1
                }
                // gotMinifig.behavior.notify(["FAN": part]) -- stub
            } else {
                switch_ = 0
            }
            airjet_cycle += 1
            if airjet_cycle > 7 {
                airjet_cycle = 1
            }
            // Render airjet sprites -- stub
            for i in 0..<2 {
                if airjet_height[i] > 0 {
                    // s.visible = 1; s.member = member("fanAir_\(airjet_height[i])_\(airjet_cycle)") -- stub
                    // s.loc = partloc + point((i+1)*15 + 2, -19); s.locZ = top_locz -- stub
                } else {
                    // s.visible = 0 -- stub
                }
            }
        }
    }

    func updatePart() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // playfield_manager.placePiece(part) -- stub
    }
}
