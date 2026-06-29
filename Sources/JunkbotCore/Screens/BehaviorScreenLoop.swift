// Translated from Lingo: behavior_screen_loop.ls

class BehaviorScreenLoop {
    var selected: Int = 0
    var data: [[String: Any]] = []
    var dataAct: [String: Any] = [:]

    func beginSprite() {
        glob["level_scrn_obj"] = self
        data = glob["building"] as! [[String: Any]]
        setBuilding((glob["current"] as! [String: Any])["building"] as! Int)
    }

    func enterFrame() {
        SndMusicEnd()
    }

    func totalMoves() {
        // no-op
    }

    func setBuilding(_ num: Int) {
        selected = num
        dataAct = data[num - 1]
        checkKeys()
        updateTabs()
        updateList()
    }

    func checkKeys() {
        for i in 1...4 {
            var keys = 0
            let building = data[i - 1]["LEVELS"] as! [[String: Any]]
            for j in 0..<building.count {
                if (building[j]["moves"] as! Int) > 0 {
                    keys += 1
                }
            }
            let keyrequired = glob["keyrequired"] as! Int
            if (i < 4) && (keys >= keyrequired) {
                data[i]["state"] = "open"
            }
        }
    }

    func updateTabs() {
        sprite(11).member = member("TAB.\(selected)")
        for sn in 1...4 {
            let state = data[sn - 1]["state"] as! String
            let num: Int
            switch state {
            case "locked":
                sprite(11 + sn + 4).member = member("building_icon_\(sn)_locked")
                num = 20
            case "open":
                sprite(11 + sn + 4).member = member("building_icon_\(sn)")
                num = selected == sn ? 100 : 50
            default:
                num = 0
            }
            sprite(11 + sn).blend = num
        }
    }

    func updateList() {
        let levels = dataAct["LEVELS"] as! [[String: Any]]
        var titleText = ""
        var movesText = ""
        for l in 0..<levels.count {
            let movesVal = levels[l]["moves"] as! Int
            let tempMoves = movesVal == 0 ? "" : String(movesVal)
            movesText += tempMoves + "\n"
            titleText += (levels[l]["title"] as! String) + "\n"
            let levelIndex = l + 1
            if movesVal > 0 {
                sprite(39 + levelIndex).member = member("checkbox_on")
                sprite(39 + levelIndex).blend = 100
                if (levels[l]["goal"] as! Int) >= movesVal {
                    sprite(54 + levelIndex).blend = 100
                } else {
                    sprite(54 + levelIndex).blend = 0
                }
                continue
            }
            sprite(39 + levelIndex).member = member("checkbox_off")
            sprite(39 + levelIndex).blend = 100
            sprite(54 + levelIndex).blend = 0
        }
        member("level.name").text = titleText
        member("level.name").fixedLinespace = 21
        member("level.moves").text = movesText
        member("level.moves").alignment = "right"
        member("level.moves").fixedLinespace = 21
    }

    func roTab(_ snum: Int, _ bnum: Int) -> Int {
        if (data[snum - 24]["state"] as! String) == "open" {
            return 0
        }
        sprite(snum - 4).blend = bnum
        return 1
    }

    func tabClicked(_ snum: Int) {
        let clicked = snum - 23
        if (data[clicked - 1]["state"] as! String) == "locked" {
            SndSFX("spring_1")
            return
        }
        if clicked == selected {
            return
        }
        SndSFX("h_powerup3")
        var current = glob["current"] as! [String: Any]
        current["building"] = clicked
        glob["current"] = current
        setBuilding(clicked)
    }

    func exitFrame() {
        go(theFrame)
    }
}
