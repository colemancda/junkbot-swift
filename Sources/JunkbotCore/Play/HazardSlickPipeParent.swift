// Translated from Lingo: parent_hazard slick pipe parent.ls

class HazardSlickPipeParent {
    var playfield_manager: Any? = nil
    var play_manager: PlayManager? = nil
    var part: [String: Any]
    var myWidth: Int = 2
    var last_step: Int = 0
    var last_drip: Int = 0
    var drip_cycle: Int = 1
    var myDrip: HazardDripParent? = nil
    var dir: Any? = nil

    init(_ p: [String: Any]) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
        part["auxSprites"] = [String: Any]()
        myWidth = 2
        let ticks = Int(Date().timeIntervalSince1970 * 60)
        last_step = ticks
        last_drip = ticks + Int.random(in: 1...240)
        drip_cycle = Int.random(in: 1...3)
    }

    func done() {
        play_manager?.actorDone(self)
        myDrip?.done()
    }

    func notify(_ notes: [String: Any]) {
        if let destroyed = notes["destroyed"] as? Int, destroyed == 1 {
            done()
        } else if notes["pos"] != nil {
            part["pos"] = notes["pos"]!
        }
    }

    func stepFrame() {
        // playfield_manager.erasePiece(part.pos) -- stub
        stepAnim()
        myDrip?.stepFrame()
        // playfield_manager.placePiece(part) -- stub
    }

    func stepAnim() {
        let t = Int(Date().timeIntervalSince1970 * 60)
        let state = part["state"] as? String ?? ""
        switch state {
        case "#DRY":
            let drip_time: Int
            if drip_cycle == 1 {
                drip_time = 160 + Int.random(in: 1...40)
            } else {
                drip_time = 80 + Int.random(in: 1...20)
            }
            if ((t - last_drip) > drip_time) && myDrip == nil {
                part["state"] = "#wet"
                last_drip = t
                drip_cycle += 1
                if drip_cycle == 4 {
                    drip_cycle = 1
                }
            }
            part["frame"] = 1
        case "#wet":
            let frame = (part["frame"] as? Int ?? 0) + 1
            if frame == 8 {
                part["frame"] = 1
                part["state"] = "#DRY"
                myDrip = HazardDripParent(self, part)
            } else {
                part["frame"] = frame
            }
        default:
            break
        }
    }

    func dripDone(_ d: HazardDripParent) {
        myDrip = nil
    }

    func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_02") -- stub
        let fig: Any? = nil // stub
        if let figDict = fig as? [String: Any] {
            SndSFX("fire")
            // figDict.behavior.notify(["damage": "#drip"]) -- stub
            _ = figDict
        }
    }
}
