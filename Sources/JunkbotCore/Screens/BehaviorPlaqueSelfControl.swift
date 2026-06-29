// Translated from Lingo: behavior_plaque_self_control_code.ls

class BehaviorPlaqueSelfControl {
    var snum: Int = 0
    var myPlaque: String = ""

    func beginSprite() {
        myPlaque = Glob.shared["plaque"].asString!
        (Glob.shared["PLAYER"]).game_manager.updatePlaque()
        sprite(snum).member = member("plaque_\(Glob.shared["plaque"].asString!)")
    }

    func exitFrame() {
        let currentPlaque = Glob.shared["plaque"].asString!
        if myPlaque != currentPlaque {
            myPlaque = currentPlaque
            sprite(snum).member = member("plaque_\(currentPlaque)")
        }
    }
}
