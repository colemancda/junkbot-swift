// Translated from Lingo: behavior_Tooltip.ls

import Foundation

class BehaviorTooltip {
    var mySprite: Any? = nil
    var getPDLError: Any? = nil
    var myString: String = "Insert your single-line tool tip here"
    var myDelay: Int = 30
    var myPosition: String = "centered"
    var myDisplaySprite: Int = 0
    var myHideFlag: Bool = true
    var myDisplayList: [Any] = []
    var myStartTicks: Int = Int.max
    var myDisplayFlag: Bool = false

    var spriteNum: Int = 0
    var spriteLeft: Int = 0
    var spriteRight: Int = 0
    var spriteTop: Int = 0
    var spriteBottom: Int = 0
    var spriteLoc: Point = Point(x: 0, y: 0)

    func getBehaviorDescription() -> String {
        return "TOOLTIP\n\nGenerates a tool tip when the user rolls over the sprite."
    }

    func getBehaviorTooltip() -> String {
        return "Use with any type of member.\n\nGenerates a tool tip message when the mouse is over the sprite."
    }

    func beginSprite() {
        initialize()
    }

    func prepareFrame() {
        checkStatus()
    }

    func mouseEnter() {
        myStartTicks = Int(Date().timeIntervalSince1970 * 60) + myDelay
    }

    func mouseLeave() {
        myStartTicks = Int.max
    }

    func initialize() {
        // mySprite = sprite(spriteNum)
        myDisplayList = []
        myStartTicks = Int.max
    }

    func checkStatus() {
        let ticks = Int(Date().timeIntervalSince1970 * 60)
        if myStartTicks < ticks {
            if myHideFlag {
                // if the mouseDown
                // if myDisplayFlag { hideTip(); return }
                // return
            }
            if myDisplayFlag {
                return
            }
            showTip()
        } else {
            if myDisplayFlag {
                hideTip()
            }
        }
    }

    func showTip() {
        myDisplayFlag = true
        var displayLoc: Point = Point(x: 0, y: 0)
        var theAlignment: String = ""

        switch myPosition {
        case "centered above":
            theAlignment = "bottomCenter"
            displayLoc = Point(x: (spriteLeft + spriteRight) / 2, y: spriteTop)
        case "centered below":
            displayLoc = Point(x: (spriteLeft + spriteRight) / 2, y: spriteBottom)
            theAlignment = "topCenter"
        case "at topLeft":
            displayLoc = Point(x: spriteLeft, y: spriteTop)
            theAlignment = "topLeft"
        case "at topRight":
            displayLoc = Point(x: spriteRight, y: spriteTop)
            theAlignment = "topright"
        case "centered":
            let centerH = (spriteLeft + spriteRight) / 2
            let centerV = (spriteTop + spriteBottom) / 2
            displayLoc = Point(x: centerH, y: centerV)
            theAlignment = "center"
        case "at bottomLeft":
            displayLoc = Point(x: spriteLeft, y: spriteBottom)
            theAlignment = "bottomleft"
        case "at bottomRight":
            displayLoc = Point(x: spriteRight, y: spriteBottom)
            theAlignment = "bottomright"
        case "at regPoint":
            displayLoc = spriteLoc
            theAlignment = "center"
        case "under the mouse":
            // displayLoc = the mouseLoc (stub)
            displayLoc = Point(x: 0, y: 0)
            theAlignment = "center"
        default:
            break
        }

        if myDisplayList.isEmpty {
            enrollDisplaySprite()
        }
        // call(#DisplayText_SetText, myDisplayList, myString, displayLoc, theAlignment)
        // stub: send DisplayText_SetText to enrolled display behaviors
    }

    func hideTip() {
        myDisplayFlag = false
        if myDisplayList.isEmpty {
            enrollDisplaySprite()
        }
        // call(#DisplayText_SetText, myDisplayList, "")
        // stub: clear display text
    }

    func enrollDisplaySprite() {
        // sendSprite(myDisplaySprite, #DisplayText_Enroll, myDisplayList)
        // if myDisplayList.isEmpty: sendAllSprites(#DisplayText_Enroll, myDisplayList)
        // if still empty: errorAlert(#noValidSprites)
        // else: errorAlert(#invalidSpriteNumber)
    }

    func getDisplaySprite() -> Int {
        // Searches for the sprite with the Display Text behavior attached
        // Returns that sprite number or currentSpriteNum + 1
        return spriteNum + 1
    }

    func tooltip_SetMessage(_ theString: String) -> String? {
        myString = theString
        return nil
    }

    func tooltip_GetReference() -> BehaviorTooltip {
        return self
    }

    func errorAlert(theError: String, data: Any?) {
        switch theError {
        case "invalidSpriteNumber":
            print("Sprite \(String(describing: data)) did not respond to a DisplayText call. Another sprite will be used.")
        case "noValidSprites":
            print("BEHAVIOR ERROR: No sprites responded to a DisplayText call. Please ensure that the 'Display Text' behavior is attached to a Field or Text Sprite.")
        default:
            break
        }
    }

    func substituteStrings(_ parentString: String, childStringList: [String: Any]) -> String {
        var result = parentString
        for (key, value) in childStringList {
            result = result.replacingOccurrences(of: key, with: "\(value)")
        }
        return result
    }

    func isOKToAttach(aSpriteType: String) -> Bool {
        return aSpriteType == "graphic"
    }
}
