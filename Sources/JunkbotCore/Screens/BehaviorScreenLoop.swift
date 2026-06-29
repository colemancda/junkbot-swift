// Translated from Lingo: behavior_screen_loop.ls

class BehaviorScreenLoop {
    var selected: Int = 0
    var data: LingoList = LingoList()
    var dataAct: PropList = PropList()

    func beginSprite() {
        Glob.shared["level_scrn_obj"] = .void  // set externally as object reference
        data = Glob.shared["building"].asList!
        let current = Glob.shared["current"].asPropList!
        setBuilding(current["building"].asInt!)
    }

    func enterFrame() {
        SndMusicEnd()
    }

    func totalMoves() {
        // no-op
    }

    func setBuilding(_ num: Int) {
        selected = num
        dataAct = data[num].asPropList!
        checkKeys()
        updateTabs()
        updateList()
    }

    func checkKeys() {
        for i in 1...4 {
            var keys = 0
            let building = data[i].asPropList!["LEVELS"].asList!
            for j in 1...building.count {
                if (building[j].asPropList!["moves"].asInt ?? 0) > 0 {
                    keys += 1
                }
            }
            let keyrequired = Glob.shared["keyrequired"].asInt!
            if (i < 4) && (keys >= keyrequired) {
                data[i + 1].asPropList!["state"] = .string("open")
            }
        }
    }

    func updateTabs() {
        sprite(11).member = member("TAB.\(selected)")
        for sn in 1...4 {
            let entry = data[sn].asPropList!
            let state = entry["state"].asString!
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
        let levels = dataAct["LEVELS"].asList!
        var titleText = ""
        var movesText = ""
        for l in 1...levels.count {
            let levelEntry = levels[l].asPropList!
            let movesVal = levelEntry["moves"].asInt ?? 0
            let tempMoves = movesVal == 0 ? "" : String(movesVal)
            movesText += tempMoves + "\n"
            titleText += (levelEntry["title"].asString ?? "") + "\n"
            if movesVal > 0 {
                sprite(39 + l).member = member("checkbox_on")
                sprite(39 + l).blend = 100
                if (levelEntry["goal"].asInt ?? 0) >= movesVal {
                    sprite(54 + l).blend = 100
                } else {
                    sprite(54 + l).blend = 0
                }
                continue
            }
            sprite(39 + l).member = member("checkbox_off")
            sprite(39 + l).blend = 100
            sprite(54 + l).blend = 0
        }
        member("level.name").text = titleText
        member("level.moves").text = movesText
    }

    func roTab(_ snum: Int, _ bnum: Int) -> Int {
        if (data[snum - 24].asPropList!["state"].asString == "open") {
            return 0
        }
        sprite(snum - 4).blend = bnum
        return 1
    }

    func tabClicked(_ snum: Int) {
        let clicked = snum - 23
        if data[clicked].asPropList!["state"].asString == "locked" {
            SndSFX("spring_1")
            return
        }
        if clicked == selected {
            return
        }
        SndSFX("h_powerup3")
        let current = Glob.shared["current"].asPropList!
        current["building"] = .int(clicked)
        setBuilding(clicked)
    }

    func exitFrame() {
        go(theFrame)
    }
}
