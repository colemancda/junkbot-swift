// Translated from Lingo: parent_minifig walk parent.ls

class MinifigWalkParent {
    var playfield_manager: Any? = nil
    var play_manager: PlayManager? = nil
    var part: [String: Any]
    var myWidth: Int = 2
    var speed: Int = 4
    var step_up: Int = 1
    var step_down: Int = 1
    var fall_down: Int = 0
    var jump_over: Int = 1
    var last_step: Int = 0
    var painmode: Int = 0
    var painTicks: Any? = nil
    var frameMax: Int = 10
    var frameCounter: Int = 1
    var fanMode: Int = 0
    var mode: String = "#WALK"
    var SHIELD: Int = 0
    var shieldticks: Int? = nil
    var cause_of_death: String? = nil
    var jump_trajectory_r: [[String: Any]] = []
    var jump_index: Int = 1
    var dir: Int = 1

    init(_ p: [String: Any]) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
        painmode = 0
        fanMode = 0
        mode = "#WALK"
        myWidth = 2
        SHIELD = 0
        shieldticks = nil

        let state = p["state"] as? String ?? ""
        if state == "#WALK_R" {
            dir = 1
        } else if state == "#walk_l" {
            dir = -1
        } else {
            dir = (Int.random(in: 1...2) * 2) - 3
        }

        speed = 4
        step_up = 1
        step_down = 1
        fall_down = 0
        jump_over = 1
        last_step = Int(Date().timeIntervalSince1970 * 60)
        frameMax = 10
        frameCounter = 1
        jump_trajectory_r = [
            ["v": [0, -1], "o": Point(x: 4, y: 0)],
            ["v": [1, -1], "o": Point(x: -2, y: 0)],
            ["v": [1, -1], "o": Point(x: 0, y: 0)],
            ["v": [1,  0], "o": Point(x: 0, y: 0)],
            ["v": [1,  1], "o": Point(x: 2, y: 0)],
            ["v": [1,  1], "o": Point(x: -4, y: 0)],
            ["v": [0,  1], "o": Point(x: 0, y: 0)]
        ]
    }

    func done() {
        play_manager?.actorDone(self)
    }

    func notify(_ notes: [String: Any]) {
        if let destroyed = notes["destroyed"] as? Int, destroyed == 1 {
            done()
        } else if let pos = notes["pos"] {
            part["pos"] = pos
        } else if let damage = notes["damage"] as? String {
            if mode != "#DEAD" {
                if SHIELD == 1 {
                    if shieldticks == nil {
                        shieldticks = Int(Date().timeIntervalSince1970 * 60) + 120
                    }
                } else {
                    frameCounter = 1
                    part["frame"] = 1
                    mode = "#DEAD"
                    cause_of_death = damage
                    switch damage {
                    case "#drip":
                        part["state"] = "#DEAD_DRIP"
                    default:
                        part["state"] = "#DEAD_GENERIC"
                    }
                }
            }
        } else if notes["FAN"] != nil && cause_of_death == nil {
            fanMode = 1
        } else if notes["jump"] != nil {
            if mode != "#jump" {
                mode = "#jump"
                jump_index = 1
            }
        } else if notes["SHIELD"] != nil {
            SndSFX("h_powerup1")
            SndSFX("shieldon2")
            mode = "#SHIELDON"
            part["frame"] = 1
            frameCounter = 1
            if dir < 0 {
                part["state"] = "#SHIELDON_L"
            } else {
                part["state"] = "#SHIELDON_R"
            }
            SHIELD = 1
            shieldticks = nil
        }
    }

    func step() {
        // pos = part.pos + point(dir, 0) -- stub
        var ok = false
        // fg = playfield_manager.checkFitOrGoal(pos, part.type) -- stub
        let fg: Any? = nil // stub
        _ = fg
        // if fg != 0 { if playfield_manager.checkFloor(pos, 2) { ok = true; doWalkState(); part.pos = pos } }
        if !ok {
            for s in 1...step_down {
                // pos = part.pos + point(dir, 0) + point(0, s) -- stub
                _ = s
                // fg = playfield_manager.checkFitOrGoal(pos, part.type) -- stub
                // if fg != 0 && playfield_manager.checkFloor(pos, 2) { ok = true; doWalkState(); part.pos = pos; break }
            }
        }
        if !ok {
            for s in 1...step_up {
                // pos = part.pos + point(dir, 0) + point(0, -s) -- stub
                _ = s
                // fg = playfield_manager.checkFitOrGoal(pos, part.type) -- stub
                // if fg != 0 && playfield_manager.checkFloor(pos, 2) { ok = true; doWalkState(); part.pos = pos; break }
            }
        }
        if !ok {
            dir = -dir
            doWalkState()
            SndSFX("turn1")
        }
        // if ilk(fg) = #propList { eat animation, erase piece } -- stub
    }

    func doWalkState() {
        let ticks = Int(Date().timeIntervalSince1970 * 60)
        if dir < 0 {
            if SHIELD == 1 {
                if let st = shieldticks {
                    if ((st - ticks) / 6) % 2 == 1 {
                        part["state"] = "#walk_l"
                    } else {
                        part["state"] = "#SHIELDWALK_L"
                    }
                } else {
                    part["state"] = "#SHIELDWALK_L"
                }
            } else {
                part["state"] = "#walk_l"
            }
        } else {
            if SHIELD == 1 {
                if let st = shieldticks {
                    if ((st - ticks) / 10) % 2 == 1 {
                        part["state"] = "#WALK_R"
                    } else {
                        part["state"] = "#SHIELDWALK_R"
                    }
                } else {
                    part["state"] = "#SHIELDWALK_R"
                }
            } else {
                part["state"] = "#WALK_R"
            }
        }
    }

    func stepAnim() {
        part["frame"] = frameCounter
        frameCounter += 1
        if frameCounter > frameMax {
            frameCounter = 1
        }
    }

    func fanAnim() {
        // pos = part.pos + point(0, -1) -- stub
        // fit = playfield_manager.checkFit(pos, part.type) -- stub
        // if fit { part.pos = pos }
    }

    func fallAnim() -> Bool {
        // if not playfield_manager.checkFloor(part.pos, 2) -- stub
        let onFloor = true // stub
        if !onFloor {
            // pos = part.pos + point(0, 1) -- stub
            // if playfield_manager.checkFit(pos, part.type) { part.pos = pos }
            if mode != "#FALL" && mode != "#DEAD" {
                SndSFX("fall")
                mode = "#FALL"
            }
            return true
        } else {
            if mode == "#FALL" {
                mode = "#WALK"
            }
            return false
        }
    }

    func jumpAnim() {
        if jump_index > jump_trajectory_r.count {
            if mode != "#FALL" {
                SndSFX("fall")
            }
            mode = "#FALL"
            part["pixelOffset"] = nil
        } else {
            var traj = jump_trajectory_r[jump_index - 1]
            if dir == 0 {
                dir = (Int.random(in: 1...2) * 2) - 3
                print("jumping without a known direction!")
            }
            if var v = traj["v"] as? [Int] {
                v[0] = v[0] * dir
                traj["v"] = v
            }
            if let o = traj["o"] as? Point {
                traj["o"] = Point(x: o.x * dir, y: o.y)
            }
            // pos = part.pos + traj["v"] -- stub
            // if playfield_manager.checkFit(pos, part.type) { ... } -- stub
            jump_index += 1
        }
    }

    func stepFrame() {
        // playfield_manager.erasePiece(part.pos) -- stub
        let ticks = Int(Date().timeIntervalSince1970 * 60)
        if (mode == "#WALK" || mode == "#FAN") && (part["frame"] as? Int == 1) && shieldticks != nil {
            if let st = shieldticks, ticks > st {
                SHIELD = 0
                SndSFX("h_powerdown3", nil, 125)
                part["frame"] = 1
                frameCounter = 1
                shieldticks = nil
            }
        }
        if mode == "#jump" {
            jumpAnim()
        } else {
            stepAnim()
            if fanMode != 0 {
                fanAnim()
            } else {
                if fallAnim() {
                    // nothing
                }
            }
            if mode == "#EAT" {
                if dir < 0 {
                    if SHIELD == 1 {
                        part["state"] = "#SHIELDEAT_L"
                    } else {
                        part["state"] = "#EAT_L"
                    }
                } else {
                    if SHIELD == 1 {
                        part["state"] = "#SHIELDEAT_R"
                    } else {
                        part["state"] = "#EAT_R"
                    }
                }
                frameMax = 19
                if frameCounter == frameMax {
                    part["frame"] = 1
                    frameCounter = 1
                    mode = "#WALK"
                    doWalkState()
                    play_manager?.addStatus("#goals", 1)
                }
            } else if mode == "#SHIELDON" || mode == "#SHIELDOFF" {
                if mode == "#SHIELDON" {
                    frameMax = 14
                } else {
                    frameMax = 11
                }
                if frameCounter >= (frameMax - 1) {
                    frameCounter = 1
                    part["frame"] = 1
                    mode = "#WALK"
                    frameMax = 10
                    doWalkState()
                }
            } else if (mode == "#WALK" || mode == "#FALL") && fanMode == 0 {
                frameMax = 10
                if mode == "#WALK" {
                    if frameCounter == 6 {
                        step()
                    } else if frameCounter == 1 {
                        step()
                    }
                }
                doWalkState()
            } else if mode == "#DEAD" {
                frameMax = 13
                if frameCounter >= (frameMax - 1) {
                    part["frame"] = 1
                    frameCounter = 1
                    frameMax = 1
                    part["state"] = "#DEAD_STILL"
                    play_manager?.addStatus("#damage", 1)
                }
            }
        }
        if let frame = part["frame"] as? Int, frame > frameMax {
            part["frame"] = frameMax
        }
        // playfield_manager.placePiece(part) -- stub
        fanMode = 0
    }
}
