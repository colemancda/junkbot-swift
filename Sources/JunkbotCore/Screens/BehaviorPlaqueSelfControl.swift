// Translated from Lingo: behavior_plaque_self_control_code.ls

class BehaviorPlaqueSelfControl {
    var snum: Int = 0
    var myPlaque: String = ""

    func beginSprite() {
        myPlaque = glob["plaque"] as! String
        (glob["PLAYER"] as AnyObject).game_manager.updatePlaque()
        sprite(snum).member = member("plaque_\(glob["plaque"] as! String)")
    }

    func exitFrame() {
        let currentPlaque = glob["plaque"] as! String
        if myPlaque != currentPlaque {
            myPlaque = currentPlaque
            sprite(snum).member = member("plaque_\(currentPlaque)")
        }
    }
}
