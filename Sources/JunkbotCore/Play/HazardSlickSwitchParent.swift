// Translated from Lingo: parent_hazard slick switch parent.ls

class HazardSlickSwitchParent {
    var play_manager: PlayManager? = nil
    var playfield_manager: Any? = nil
    var part: [String: Any]
    var stepped_on: Int = 0

    init(_ p: [String: Any]) {
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = nil // play_manager.playfield_manager
        stepped_on = 0
    }

    func notify(_ args: [String: Any]) {
        if let sw = args["switch"] {
            part["state"] = sw
            redrawPart()
        }
    }

    func done() {
        play_manager?.actorDone(self)
    }

    func stepFrame() {
        checkMiniFig()
    }

    func checkMiniFig() {
        // fig = playfield_manager.checkFitOrMinifig(part.pos + point(0, -1), "#BRICK_01") -- stub
        let fig: Any? = nil // stub
        // fig2 = playfield_manager.checkFitOrMinifig(part.pos + point(1, -1), "#BRICK_01") -- stub
        let fig2: Any? = nil // stub

        let figIsDict = fig is [String: Any]
        let fig2IsDict = fig2 is [String: Any]
        // (fig == fig2) && ilk(fig) == #propList
        if figIsDict && fig2IsDict {
            if let figDict = fig as? [String: Any], let fig2Dict = fig2 as? [String: Any] {
                _ = figDict; _ = fig2Dict
                if stepped_on == 0 {
                    stepped_on = 1
                    let state = part["state"] as? String ?? ""
                    if state == "#off" {
                        part["state"] = "#on"
                        SndSFX("switch_on")
                        SndSFX("switch_click")
                    } else {
                        part["state"] = "#off"
                        SndSFX("switch_off")
                        SndSFX("switch_click")
                    }
                    let label = part["label"] as? String ?? ""
                    play_manager?.doSwitch(["label": label, "state": part["state"] as Any])
                    part["frame"] = 1
                }
            }
        } else {
            stepped_on = 0
        }
    }

    func redrawPart() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // playfield_manager.placePiece(part) -- stub
    }
}
