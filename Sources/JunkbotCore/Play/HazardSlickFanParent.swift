// Translated from Lingo: parent_hazard slick fan parent.ls

public class HazardSlickFanParent {
    public var playfield_manager: LV = .void
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var last_step: Int = 0
    public var switch_: Int = 0  // 'switch' is a Swift keyword, renamed to switch_
    public var airjet_cycle: Int = 1
    public var partloc: Point = Point()
    public var top_locz: LV = .void
    public var dir: LV = .void

    public init(_ p: PropList) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        // partloc = part.sprite[1].loc -- stub
        myWidth = 2
        last_step = currentTicks
        switch_ = 0
        airjet_cycle = lingoRandom(7)
        // top_locz = playfield_manager.posToLocZ(point(50, 1)) -- stub
    }

    public func done() {
        if let pm = play_manager { pm.actorDone(self) }
    }

    public func notify(_ notes: PropList) {
        if let destroyed = notes["destroyed"].asInt, destroyed == 1 {
            done()
        } else if !notes["pos"].isVoid {
            part["pos"] = notes["pos"]
        } else if !notes["switch"].isVoid {
            part["state"] = notes["switch"]
            stepAnim()
            updatePart()
        }
    }

    public func stepFrame() {
        stepAnim()
        updatePart()
        checkMiniFig()
    }

    public func stepAnim() {
        let state = part["state"].asString ?? ""
        if state == "#on" {
            let frame = part["frame"].asInt ?? 1
            part["frame"] = .int((frame % 4) + 1)
        } else {
            part["frame"] = .int(1)
        }
    }

    public func checkMiniFig() {
        let state = part["state"].asString ?? ""
        var gotMinifig: LV = .void
        var airjet_height = [0, 0]
        if state == "#on" {
            var y = -1
            while true {
                // fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, y), "#BRICK_01") -- stub
                let fig: LV = .int(1) // stub
                if let figInt = fig.asInt, figInt == 0 { break }
                if fig.isPropList {
                    gotMinifig = fig
                    break
                }
                y -= 1
                airjet_height[0] += 1
            }
            y = -1
            while true {
                // fig = playfield_manager.checkFitOrMinifig(part.pos + point(2, y), "#BRICK_01") -- stub
                let fig: LV = .int(1) // stub
                if let figInt = fig.asInt, figInt == 0 { break }
                if fig.isPropList {
                    gotMinifig = fig
                    break
                }
                y -= 1
                airjet_height[1] += 1
            }
            if gotMinifig.isPropList {
                if switch_ == 0 {
                    SndSFX("fan")
                    switch_ = 1
                }
                // gotMinifig.asPropList!.behavior.notify(["FAN": part]) -- stub
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
                _ = i
            }
        }
    }

    public func updatePart() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // playfield_manager.placePiece(part) -- stub
    }
}
