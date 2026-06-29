// Translated from Lingo: behavior_level end dialog buttons behavior.ls

class BehaviorLevelEndDialogButtons {
    var which: String = "none"
    var spriteNum: Int = 0

    func mouseUp() {
        if sprite(spriteNum).blend == 0 {
            return
        }
        switch which {
        case "com_nextlevel":
            let level = (glob["current"] as! [String: Any])["level"] as! Int
            let building = (glob["current"] as! [String: Any])["building"] as! Int
            if (level == 15) && !(building == 4) {
                let lock = (glob["building"] as! [[String: Any]])[building]["state"] as! String
                if lock == "open" {
                    var current = glob["current"] as! [String: Any]
                    current["building"] = building + 1
                    glob["current"] = current
                }
            }
            (glob["BIG_MSG_OBJ"] as AnyObject).updateState("move2", ["object": (glob["PLAYER"] as AnyObject).game_manager, "parameter": "com_nextlevel"])
        case "com_selectlevel":
            (glob["BIG_MSG_OBJ"] as AnyObject).updateState("move2", ["object": (glob["PLAYER"] as AnyObject).game_manager, "parameter": "select_level"])
        case "fail_tryagain":
            (glob["fail_msg_obj"] as AnyObject).updateState("move2", ["object": (glob["PLAYER"] as AnyObject).game_manager, "parameter": "restart_level"])
        case "fail_gethint":
            (glob["hint_obj"] as AnyObject).updateState("move2")
        case "fail_selectlevel":
            (glob["fail_msg_obj"] as AnyObject).updateState("move2", ["object": (glob["PLAYER"] as AnyObject).game_manager, "parameter": "select_level"])
        default:
            break
        }
    }

    func mouseDown() {
        if sprite(spriteNum).blend == 0 {
            return
        }
        SndSFX("h_button1")
    }

    // Property description: which is #propList with range [#com_nextlevel, #fail_tryagain, #fail_gethint, #fail_selectlevel], default #none
}
