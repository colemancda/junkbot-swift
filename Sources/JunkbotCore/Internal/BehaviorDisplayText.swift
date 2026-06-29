// Translated from Lingo: behavior_Display Text.ls

class BehaviorDisplayText: BehaviorBase {
    var spriteNum: Int = 0
    var getPDLError: LV = .void
    var myDisplayType: String = "status bar (fixed size and position)"
    var mySprite: LV = .void
    var myMember: LV = .void
    var myWidthAdjust: Int = 0
    var myHeightAdjust: Int = 0
    var myOffStageLoc: Point = Point(x: 999, y: 999)

    func getBehaviorDescription() -> String {
        return "DISPLAY TEXT" + "\n\n" +
            "This behavior allows you to display a given string in a field or text member. " +
            "Use it with the Tooltip and Hypertext - Display Status behaviors which need a field or text member in which to display their information. " +
            "Or create your own custom Lingo to display runtime information, such as the position of the mouse." + "\n\n" +
            "This behavior waits for Lingo commands to tell it what to do. " +
            "It is not active by itself." + "\n\n" +
            "You can choose between two display types: tooltip and status bar." + "\n\n" +
            "The TOOLTIP type of display will make the field or text member resize itself to fit the text, and disappear when it is empty. " +
            "You can set the tooltip type display to appear at any position on the stage, such as under the cursor. " +
            "If no position is sent to the sprite, it will appear at the top left corner of the Stage. " +
            "See the Tooltip behavior for more details." + "\n\n" +
            "If you wish to display several lines of text, you must use RETURN characters to define the line breaks. " +
            "An empty tooltip sprite will move off-stage to hide. " +
            "It is recommended that you place it off-stage before it is used, in case it causes a brief flash on the screen." + "\n\n" +
            "The STATUS BAR type of display will appear on Stage at all times. " +
            "It will not resize or change position. " +
            "Any positional information sent to this sprite will be ignored if it is set to act as a status bar. " +
            "If the text is too long to appear in the member of the current sprite, a scrollbar will appear. " +
            "You do not need to divide the text with RETURN characters. " +
            "If you think that a scrollbar may be necessary, make sure that the field or text member is sufficiently tall for the scroll arrows to operate correctly." + "\n\n" +
            "Set the font size and other characteristics of the field or text member to customize the appearance of the message." + "\n\n" +
            "Be sure to give the field or text member a name. " +
            "It may be emptied by this behavior. " +
            "Director automatically erases nameless empty members." + "\n\n" +
            "PERMITTED MEMBER TYPES:\nfield and text\n\n" +
            "PARAMETERS:\n* Display type:\n  - Tooltip (appears near the cursor on rollover)\n  - Status bar (appears in a fixed position at all times)\n\n" +
            "PUBLIC METHODS:\n* Set the text to display (and the position of the sprite)\n\n" +
            "ASSOCIATED BEHAVIORS:\n* Tooltip\n* Source Status\n* Hypertext - Display Status"
    }

    func getBehaviorTooltip() -> String {
        return "Use with field or text members." + "\n\n" +
            "Waits for a message from another behavior or custom handler to display a character string. " +
            "This behavior is intended to be used with the Tooltip and Hypertext - Display Status behaviors to create a status bar or a tooltip under the cursor."
    }

    func beginSprite() {
        myDisplayType = resolve(myDisplayType)
        initialize()
    }

    func endSprite() {
        // mySprite.visible = 1  (stub: set sprite visible)
    }

    func resolve(_ prop: String) -> String {
        let choicesList = ["status bar (fixed size and position)", "tooltip (dynamic size and position)"]
        let lookup = ["statusbar", "tooltip"]
        if let idx = choicesList.firstIndex(of: prop) {
            return lookup[idx]
        }
        return prop
    }

    func initialize() {
        // mySprite = sprite(spriteNum)
        // myMember = mySprite.member
        // Member margin/border adjustments would be set here based on member type
        myWidthAdjust = 0
        myHeightAdjust = 0
        // myMember.text = ""
        if myDisplayType == "tooltip" {
            // myMember.boxType = "fixed"
            myOffStageLoc = Point(x: 999, y: 999)
            // mySprite.loc = myOffStageLoc
        }
    }

    // BestRect: calculates the best rect for a given string in the member
    func bestRect(_ theString: String) -> [Int] {
        // Stub: would measure text dimensions via member API
        // Returns [left, top, right, bottom]
        return [0, 0, 0, 0]
    }

    func getTopLeft(theLoc: Point, theAlignment: String, memberRect: [Int]) -> Point {
        let width = memberRect.count > 2 ? memberRect[2] - memberRect[0] : 0
        let height = memberRect.count > 3 ? memberRect[3] - memberRect[1] : 0
        switch theAlignment {
        case "bottomCenter":
            return Point(x: theLoc.x - width / 2, y: theLoc.y - height)
        case "bottomright":
            return Point(x: theLoc.x - width, y: theLoc.y - height)
        case "bottomleft":
            return Point(x: theLoc.x - 0, y: theLoc.y - height)
        case "center":
            return Point(x: theLoc.x - width / 2, y: theLoc.y - height / 2)
        case "topCenter":
            return Point(x: theLoc.x - width / 2, y: theLoc.y - 0)
        case "topright":
            return Point(x: theLoc.x - width, y: theLoc.y - 0)
        default:
            return theLoc
        }
    }

    func displayText_Enroll(_ enrollList: LingoList) -> LingoList {
        if enrollList.count == 0 {
            enrollList.add(.void)  // placeholder — would store self reference via protocol
        }
        return enrollList
    }

    func displayText_SetText(_ theString: String?, theLoc: Point? = nil, theAlignment: String? = nil) {
        var str = theString ?? ""

        if theString == nil {
            errorAlert(theError: "invalidString")
            str = ""
        }

        if str == "" && myDisplayType == "tooltip" {
            // mySprite.loc = myOffStageLoc
            return
        }

        // myMember.text = str
        var memberRect: [Int]
        if myDisplayType == "tooltip" {
            memberRect = bestRect(str)
            // myMember.rect = memberRect
        } else {
            memberRect = [0, 0, 0, 0] // myMember.rect
        }

        // memberRect += [0, 0, myWidthAdjust, myHeightAdjust]

        if myDisplayType == "tooltip" {
            let loc = theLoc ?? Point(x: 0, y: 0)
            let resolvedLoc = getTopLeft(theLoc: loc, theAlignment: theAlignment ?? "", memberRect: memberRect)
            // stageWidth / stageHeight clamping would happen here
            // mySprite.loc = resolvedLoc
            _ = resolvedLoc
        } else {
            // Check if scroll needed based on text height vs sprite height
            // myMember.boxType = textHeight > mySprite.height ? "scroll" : "fixed"
        }
    }

    func displayText_GetReference() -> BehaviorDisplayText {
        return self
    }

    func errorAlert(theError: String) {
        switch theError {
        case "invalidString":
            debugLog("BEHAVIOR ERROR: DisplayText_SetText handler could not treat value as a string")
        case "invalidPoint":
            debugLog("BEHAVIOR ERROR: DisplayText_SetText handler could not treat value as a point")
        default:
            break
        }
    }

    func substituteStrings(_ parentString: String, childStringList: PropList) -> String {
        var result = parentString
        for i in 1...max(1, childStringList.count) {
            guard i <= childStringList.count else { break }
            let (key, value) = childStringList.getPropAt(i)
            result = result.replacingOccurrences(of: key, with: value.asString ?? "")
        }
        return result
    }

    func isOKToAttach(aSpriteType: String, aSpriteNum: Int) -> Bool {
        switch aSpriteType {
        case "graphic":
            // return true if sprite member type is field or text
            return false // stub
        case "script":
            return false
        default:
            return false
        }
    }
}
