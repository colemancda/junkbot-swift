// Translated from Lingo: behavior_catalog disable until net ready.ls

class BehaviorCatalogDisableUntilNetReady {
    var s: Sprite? = nil
    var m: Member? = nil

    init(_ spriteNum: Int) {
        s = sprite(spriteNum)
        m = s?.member
    }

    func netReady(_ flag: Int) {
        if flag == 1 {
            s?.blend = 100
        } else {
            s?.blend = 30
        }
    }
}
