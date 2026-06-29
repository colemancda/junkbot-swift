// Translated from Lingo: parent_hazard climb parent.ls

class HazardClimbParent {
    var playfield_manager: Any? = nil
    var play_manager: PlayManager? = nil
    var part: [String: Any]
    var myWidth: Int = 2
    var speed: Int = 4
    var climb_up: Int = 3
    var jump_over: Int = 1
    var last_step: Int = 0
    var dir: Point = Point(x: 1, y: 0)
    var climbstart: Int = 0
    var oldhoriz: Int = 1

    init(_ p: [String: Any]) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
        myWidth = 2
        let state = p["state"] as? String ?? ""
        if state == "#walk_l" {
            dir = Point(x: -1, y: 0)
        } else if state == "#WALK_R" {
            dir = Point(x: 1, y: 0)
        } else if state == "#FLOAT_UP" {
            dir = Point(x: 0, y: -1)
        } else {
            dir = Point(x: 0, y: 1)
        }
        oldhoriz = 1
        speed = 4
        climb_up = 3
        jump_over = 1
        // climbstart = part.pos[2] -- stub
        climbstart = (p["pos"] as? Point)?.y ?? 0
        last_step = Int(Date().timeIntervalSince1970 * 60)
    }

    func done() {
        play_manager?.actorDone(self)
    }

    func notify(_ notes: [String: Any]) {
        if let destroyed = notes["destroyed"] as? Int, destroyed == 1 {
            done()
        } else if notes["pos"] != nil {
            part["pos"] = notes["pos"]!
        }
    }

    func step() {
        Glob.shared["minifigHit"] = nil
        // playfield_manager.erasePiece(part.pos) -- stub
        let state = part["state"] as? String ?? ""
        let partPos = part["pos"] as? Point ?? Point(x: 0, y: 0)

        switch state {
        case "#FLOAT_UP":
            let tdir = Point(x: oldhoriz, y: 0)
            // complex movement logic — see Lingo source for full details
            // if (partPos.y == climbstart) && playfield_manager.checkFitMiniFigHit(partPos + dir, part.type) {
            //     part.pos = partPos + dir
            // } else if playfield_manager.checkFitMiniFigHit(partPos + tdir, part.type) && playfield_manager.checkFloor(partPos + tdir, myWidth) > 0 {
            //     dir = tdir; part.pos = partPos + dir
            // } else if playfield_manager.checkFitMiniFigHit(partPos - tdir, part.type) && playfield_manager.checkFloor(partPos - tdir, myWidth) > 0 {
            //     dir = Point(x: -tdir.x, y: -tdir.y); part.pos = partPos + dir
            // } else if (climbstart - partPos.y) >= climb_up {
            //     dir = Point(x: -dir.x, y: -dir.y)
            // } else if playfield_manager.checkFitMiniFigHit(partPos + dir, part.type) {
            //     part.pos = partPos + dir
            // } else {
            //     dir = Point(x: -dir.x, y: -dir.y)
            // }
            _ = tdir
        case "#FLOAT_DOWN":
            let tdir = Point(x: oldhoriz, y: 0)
            // if playfield_manager.checkFitMiniFigHit(partPos + dir, part.type) {
            //     part.pos = partPos + dir
            // } else if playfield_manager.checkFitMiniFigHit(partPos + tdir, part.type) {
            //     dir = tdir; part.pos = partPos + dir
            // } else if playfield_manager.checkFitMiniFigHit(partPos - tdir, part.type) {
            //     dir = Point(x: -tdir.x, y: -tdir.y); part.pos = partPos + dir
            // } else {
            //     dir = Point(x: 0, y: -1); climbstart = partPos.y
            // }
            _ = tdir
        case "#walk_l", "#WALK_R":
            // if playfield_manager.checkFloor(partPos, myWidth) == 0 && playfield_manager.checkFitMiniFigHit(partPos + Point(x:0,y:1), part.type) {
            //     oldhoriz = dir.x; dir = Point(x:0, y:1); part.pos = partPos + dir
            // } else if !playfield_manager.checkFitMiniFigHit(partPos + dir, part.type) {
            //     oldhoriz = dir.x; dir = Point(x:0, y:-1); climbstart = partPos.y
            // } else {
            //     part.pos = partPos + dir
            // }
            break
        default:
            break
        }

        if dir.x < 0 {
            part["state"] = "#walk_l"
        } else if dir.x > 0 {
            part["state"] = "#WALK_R"
        } else if dir.y < 0 {
            part["state"] = "#FLOAT_UP"
        } else {
            part["state"] = "#FLOAT_DOWN"
        }

        if Glob.shared["minifigHit"] != nil {
            SndSFX("robottouch4")
            // Glob.shared["minifigHit"].behavior.notify(["damage": "#climber"]) -- stub
        }
        // playfield_manager.placePiece(part) -- stub
    }

    func stepAnim() {
        if let frame = part["frame"] as? Int {
            part["frame"] = (frame % 6) + 1
        }
    }

    func stepFrame() {
        if let frame = part["frame"] as? Int, frame == 6 {
            step()
        }
        // playfield_manager.erasePiece(part.pos) -- stub
        stepAnim()
        // playfield_manager.placePiece(part) -- stub
    }
}
