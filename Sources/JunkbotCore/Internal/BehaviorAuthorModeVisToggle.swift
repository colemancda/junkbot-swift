// Translated from Lingo: behavior_authorMode_vis_toggle.ls

class BehaviorAuthorModeVisToggle {
    var spriteNum: Int = 0

    // Reference to global state (injected externally)
    var glob: [String: Any]? = nil

    func beginSprite() {
        let authorMode = (glob?["authorMode"] as? Bool) ?? false
        if authorMode {
            // nothing()
        } else {
            // sprite(spriteNum).loc = Point(x: 1000, y: 1000)
            // Move sprite off-stage
        }
    }
}
