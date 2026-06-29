// Translated from Lingo: behavior_BossMemo_script.ls

class BehaviorBossMemo {
    var snum: Int = 0

    func beginSprite() {
        Glob.shared["boss"] = .void  // set to self via object store externally
        let rankdata = Glob.shared["rankdata"].asPropList!
        if (rankdata["keys"].asInt ?? 0) > 0 {
            Glob.shared["memo"] = .string("DidIt")
        }
        if Glob.shared["memo"].asString == "show" {
            sprite(snum).loc = Point(x: 233, y: 209)
            sprite(snum + 1).loc = Point(x: 27, y: 23)
            sprite(snum + 2).loc = Point(x: 33, y: 104)
            sprite(snum + 3).loc = Point(x: 234, y: 354)
            Glob.shared["memo"] = .string("DidIt")
        } else {
            hide()
        }
    }

    func hide() {
        sprite(snum).loc = Point(x: 1000, y: 209)
        sprite(snum + 1).loc = Point(x: 1000, y: 23)
        sprite(snum + 2).loc = Point(x: 1000, y: 104)
        sprite(snum + 3).loc = Point(x: 1000, y: 354)
        updateStage()
    }
}
