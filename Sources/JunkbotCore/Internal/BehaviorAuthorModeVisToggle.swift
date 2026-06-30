// Translated from Lingo: behavior_authorMode_vis_toggle.ls

class BehaviorAuthorModeVisToggle: LingoObject, @unchecked Sendable {
    var spriteNum: Int = 0

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   if glob.authorMode then
    //     nothing()
    //   else
    //     sprite(me.spriteNum).loc = point(1000, 1000)
    //   end if
    // end
    // ```
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
