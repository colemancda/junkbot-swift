// Translated from Lingo: behavior_BossMemo_script.ls

class BehaviorBossMemo {
    var snum: Int = 0

    func beginSprite() {
        glob["boss"] = self
        glob["PLAYER"] as AnyObject
        (glob["PLAYER"] as AnyObject).game_manager.TotalKeys()
        glob["memo"] = "show"
        let rankdata = glob["rankdata"] as! [String: Any]
        if (rankdata["keys"] as! Int) > 0 {
            glob["memo"] = "DidIt"
        }
        if (glob["memo"] as! String) == "show" {
            sprite(snum).loc = Point(x: 233, y: 209)
            sprite(snum + 1).loc = Point(x: 27, y: 23)
            sprite(snum + 2).loc = Point(x: 33, y: 104)
            sprite(snum + 3).loc = Point(x: 234, y: 354)
            glob["memo"] = "DidIt"
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
