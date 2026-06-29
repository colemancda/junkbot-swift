// Translated from Lingo: behavior_authorMode_vis_toggle.ls

class BehaviorAuthorModeVisToggle: LingoObject {
    var spriteNum: Int = 0

    func beginSprite() {
        let authorMode = Glob.shared["authorMode"].asInt == 1
        if authorMode {
            // nothing()
        } else {
            // sprite(spriteNum).loc = Point(x: 1000, y: 1000)
            // Move sprite off-stage
        }
    }
}
