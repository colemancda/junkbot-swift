// Translated from Lingo: behavior_Display Text.ls

class BehaviorDisplayText: LingoObject, @unchecked Sendable {
  var spriteNum: Int = 0
  var getPDLError: LV = .void
  var myDisplayType: String = "status bar (fixed size and position)"
  var mySprite: LV = .void
  var myMember: LV = .void
  var myWidthAdjust: Int = 0
  var myHeightAdjust: Int = 0
  var myOffStageLoc: Point = Point(x: 999, y: 999)

  // Original Lingo body: getbehaviordescription
  // ```lingo
  // on getBehaviorDescription me
  //   return "DISPLAY TEXT" & RETURN & RETURN & "This behavior allows you to display a given string in a field or text member. " & "Use it with the Tooltip and Hypertext - Display Status behaviors which need a field or text member in which to display their information. " & "Or create your own custom Lingo to display runtime information, such as the position of the mouse." & RETURN & RETURN & "This behavior waits for Lingo commands to tell it what to do. " & "It is not active by itself." & RETURN & RETURN & "You can choose between two display types: tooltip and status bar." & RETURN & RETURN & "The TOOLTIP type of display will make the field or text member resize itself to fit the text, and disappear when it is empty. " & "You can set the tooltip type display to appear at any position on the stage, such as under the cursor. " & "If no position is sent to the sprite, it will appear at the top left corner of the Stage. " & "See the Tooltip behavior for more details." & RETURN & RETURN & "If you wish to display several lines of text, you must use RETURN characters to define the line breaks. " & "An empty tooltip sprite will move off-stage to hide. " & "It is recommended that you place it off-stage before it is used, in case it causes a brief flash on the screen." & RETURN & RETURN & "The STATUS BAR type of display will appear on Stage at all times. " & "It will not resize or change position. " & "Any positional information sent to this sprite will be ignored if it is set to act as a status bar. " & "If the text is too long to appear in the member of the current sprite, a scrollbar will appear. " & "You do not need to divide the text with RETURN characters. " & "If you think that a scrollbar may be necessary, make sure that the field or text member is sufficiently tall for the scroll arrows to operate correctly." & RETURN & RETURN & "Set the font size and other characteristics of the field or text member to customize the appearance of the message." & RETURN & RETURN & "Be sure to give the field or text member a name. " & "It may be emptied by this behavior. " & "Director automatically erases nameless empty members." & RETURN & RETURN & "PERMITTED MEMBER TYPES:" & RETURN & "field and text" & RETURN & RETURN & "PARAMETERS:" & RETURN & "* Display type:" & RETURN & "  - Tooltip (appears near the cursor on rollover)" & RETURN & "  - Status bar (appears in a fixed position at all times)" & RETURN & RETURN & "PUBLIC METHODS:" & RETURN & "* Set the text to display (and the position of the sprite)" & RETURN & RETURN & "ASSOCIATED BEHAVIORS:" & RETURN & "* Tooltip" & RETURN & "* Source Status" & RETURN & "* Hypertext - Display Status"
  // end
  // ```
  func getBehaviorDescription() -> String {
    return "DISPLAY TEXT" + "\n\n"
      + "This behavior allows you to display a given string in a field or text member. "
      + "Use it with the Tooltip and Hypertext - Display Status behaviors which need a field or text member in which to display their information. "
      + "Or create your own custom Lingo to display runtime information, such as the position of the mouse."
      + "\n\n" + "This behavior waits for Lingo commands to tell it what to do. "
      + "It is not active by itself." + "\n\n"
      + "You can choose between two display types: tooltip and status bar." + "\n\n"
      + "The TOOLTIP type of display will make the field or text member resize itself to fit the text, and disappear when it is empty. "
      + "You can set the tooltip type display to appear at any position on the stage, such as under the cursor. "
      + "If no position is sent to the sprite, it will appear at the top left corner of the Stage. "
      + "See the Tooltip behavior for more details." + "\n\n"
      + "If you wish to display several lines of text, you must use RETURN characters to define the line breaks. "
      + "An empty tooltip sprite will move off-stage to hide. "
      + "It is recommended that you place it off-stage before it is used, in case it causes a brief flash on the screen."
      + "\n\n" + "The STATUS BAR type of display will appear on Stage at all times. "
      + "It will not resize or change position. "
      + "Any positional information sent to this sprite will be ignored if it is set to act as a status bar. "
      + "If the text is too long to appear in the member of the current sprite, a scrollbar will appear. "
      + "You do not need to divide the text with RETURN characters. "
      + "If you think that a scrollbar may be necessary, make sure that the field or text member is sufficiently tall for the scroll arrows to operate correctly."
      + "\n\n"
      + "Set the font size and other characteristics of the field or text member to customize the appearance of the message."
      + "\n\n" + "Be sure to give the field or text member a name. "
      + "It may be emptied by this behavior. "
      + "Director automatically erases nameless empty members." + "\n\n"
      + "PERMITTED MEMBER TYPES:\nfield and text\n\n"
      + "PARAMETERS:\n* Display type:\n  - Tooltip (appears near the cursor on rollover)\n  - Status bar (appears in a fixed position at all times)\n\n"
      + "PUBLIC METHODS:\n* Set the text to display (and the position of the sprite)\n\n"
      + "ASSOCIATED BEHAVIORS:\n* Tooltip\n* Source Status\n* Hypertext - Display Status"
  }

  // Original Lingo body: getbehaviortooltip
  // ```lingo
  // on getBehaviorTooltip me
  //   return "Use with field or text members." & RETURN & RETURN & "Waits for a message from another behavior or custom handler to display a character string. " & "This behavior is intended to be used with the Tooltip and Hypertext - Display Status behaviors to create a status bar or a tooltip under the cursor."
  // end
  // ```
  func getBehaviorTooltip() -> String {
    return "Use with field or text members." + "\n\n"
      + "Waits for a message from another behavior or custom handler to display a character string. "
      + "This behavior is intended to be used with the Tooltip and Hypertext - Display Status behaviors to create a status bar or a tooltip under the cursor."
  }

  // Original Lingo body: beginsprite
  // ```lingo
  // on beginSprite me
  //   myDisplayType = resolve(myDisplayType)
  //   Initialize(me)
  // end
  // ```
  func beginSprite() {
    myDisplayType = resolve(myDisplayType)
    initialize()
  }

  // Original Lingo body: endsprite
  // ```lingo
  // on endSprite me
  //   mySprite.visible = 1
  // end
  // ```
  func endSprite() {
    // mySprite.visible = 1  (stub: set sprite visible)
  }

  // Original Lingo body: resolve
  // ```lingo
  // on resolve Prop
  //   case Prop of
  //     myDisplayType:
  //       choiceslist = ["status bar (fixed size and position)", "tooltip (dynamic size and position)"]
  //       lookup = [#statusbar, #tooltip]
  //   end case
  //   return lookup[findPos(choiceslist, Prop)]
  // end
  // ```
  func resolve(_ prop: String) -> String {
    let choicesList = [
      "status bar (fixed size and position)", "tooltip (dynamic size and position)",
    ]
    let lookup = ["statusbar", "tooltip"]
    if let idx = choicesList.firstIndex(of: prop) {
      return lookup[idx]
    }
    return prop
  }

  // Original Lingo body: initialize
  // ```lingo
  // on Initialize me
  //   mySprite = sprite(me.spriteNum)
  //   myMember = mySprite.member
  //   if myMember.type = #field then
  //     myWidthAdjust = (myMember.margin + myMember.border) * 2
  //     myHeightAdjust = myMember.margin + (myMember.border * 2)
  //   else
  //     myWidthAdjust = 0
  //     myHeightAdjust = 0
  //   end if
  //   myMember.text = EMPTY
  //   if myDisplayType = #tooltip then
  //     myMember.boxType = #fixed
  //     myOffStageLoc = point(999, 999)
  //     mySprite.loc = myOffStageLoc
  //   end if
  // end
  // ```
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
  // Original Lingo body: bestrect
  // ```lingo
  // on BestRect me, theString
  //   myMember.rect = rect(0, 0, 8000, 0)
  //   myMember.text = theString
  //   BestRect = myMember.rect
  //   theLine = the number of lines in theString
  //   theWidth = 0
  //   checkedChars = 0
  //   repeat while theLine
  //     endOfLine = offset(RETURN, theString)
  //     if not endOfLine then
  //       endOfLine = the number of chars in theString + 1
  //       myMember.text = myMember.text & RETURN
  //     end if
  //     checkedChars = checkedChars + endOfLine
  //     endPoint = charPosToLoc(myMember, checkedChars)
  //     lineWidth = endPoint[1]
  //     if lineWidth > theWidth then
  //       theWidth = lineWidth
  //     end if
  //     delete char 1 to endOfLine of theString
  //     theLine = theLine - 1
  //   end repeat
  //   lastChar = myMember.char.count
  //   lastCharLoc = charPosToLoc(myMember, lastChar)
  //   theHeight = lastCharLoc[2]
  //   BestRect[3] = theWidth + 1
  //   BestRect[4] = theHeight + 1
  //   return BestRect
  // end
  // ```
  func bestRect(_ theString: String) -> [Int] {
    // Stub: would measure text dimensions via member API
    // Returns [left, top, right, bottom]
    return [0, 0, 0, 0]
  }

  // Original Lingo body: gettopleft
  // ```lingo
  // on GetTopLeft me, theLoc, theAlignment, memberRect
  //   case theAlignment of
  //     #bottomCenter:
  //       return theLoc - [memberRect.width / 2, memberRect.height]
  //     #bottomright:
  //       return theLoc - [memberRect.width, memberRect.height]
  //     #bottomleft:
  //       return theLoc - [0, memberRect.height]
  //     #center:
  //       return theLoc - [memberRect.width / 2, memberRect.height / 2]
  //     #topCenter:
  //       return theLoc - [memberRect.width / 2, 0]
  //     #topright:
  //       return theLoc - [memberRect.width, 0]
  //     otherwise:
  //       return theLoc
  //   end case
  // end
  // ```
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

  // Original Lingo body: displaytext_enroll
  // ```lingo
  // on DisplayText_Enroll me, enrollList
  //   if ilk(enrollList) <> #list then
  //     return me
  //   end if
  //   if not enrollList.count() then
  //     enrollList.append(me)
  //   else
  //   end if
  //   return enrollList
  // end
  // ```
  func displayText_Enroll(_ enrollList: LingoList) -> LingoList {
    if enrollList.count == 0 {
      enrollList.add(.void)  // placeholder — would store self reference via protocol
    }
    return enrollList
  }

  // Original Lingo body: displaytext_settext
  // ```lingo
  // on DisplayText_SetText me, theString, theLoc, theAlignment
  //   if not stringp(theString) then
  //     ErrorAlert(me, #invalidString, theString)
  //     theString = string(theString)
  //   else
  //     case ilk(theLoc) of
  //       #void, #point:
  //       otherwise:
  //         ErrorAlert(me, #invalidPoint, theLoc)
  //         theLoc = point(0, 0)
  //     end case
  //   end if
  //   if (theString = EMPTY) and (myDisplayType = #tooltip) then
  //     mySprite.loc = myOffStageLoc
  //   else
  //     myMember.text = theString
  //     if myDisplayType = #tooltip then
  //       memberRect = BestRect(me, theString)
  //       myMember.rect = memberRect
  //     else
  //       memberRect = myMember.rect
  //     end if
  //     memberRect = memberRect + [0, 0, myWidthAdjust, myHeightAdjust]
  //     if myDisplayType = #tooltip then
  //       if ilk(theLoc) <> #point then
  //         theLoc = point(0, 0)
  //       end if
  //       theLoc = GetTopLeft(me, theLoc, theAlignment, memberRect)
  //       stageWidth = (the activeWindow).rect.right - (the activeWindow).rect.left
  //       stageHeight = (the activeWindow).rect.bottom - (the activeWindow).rect.top
  //       maxH = stageWidth - memberRect.width
  //       maxV = stageHeight - memberRect.height
  //       theLoc[1] = max(0, min(theLoc[1], maxH))
  //       theLoc[2] = max(0, min(theLoc[2], maxV))
  //       theLoc = theLoc + myMember.regPoint
  //       mySprite.loc = theLoc
  //     else
  //       lastChar = theString.char.count
  //       textHeight = charPosToLoc(myMember, lastChar)[2]
  //       if textHeight > mySprite.height then
  //         myMember.boxType = #scroll
  //       else
  //         myMember.boxType = #fixed
  //       end if
  //     end if
  //   end if
  // end
  // ```
  func displayText_SetText(_ theString: String?, theLoc: Point? = nil, theAlignment: String? = nil)
  {
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
      memberRect = [0, 0, 0, 0]  // myMember.rect
    }

    // memberRect += [0, 0, myWidthAdjust, myHeightAdjust]

    if myDisplayType == "tooltip" {
      let loc = theLoc ?? Point(x: 0, y: 0)
      let resolvedLoc = getTopLeft(
        theLoc: loc, theAlignment: theAlignment ?? "", memberRect: memberRect)
      // stageWidth / stageHeight clamping would happen here
      // mySprite.loc = resolvedLoc
      _ = resolvedLoc
    } else {
      // Check if scroll needed based on text height vs sprite height
      // myMember.boxType = textHeight > mySprite.height ? "scroll" : "fixed"
    }
  }

  // Original Lingo body: displaytext_getreference
  // ```lingo
  // on DisplayText_GetReference me
  //   return me
  // end
  // ```
  func displayText_GetReference() -> BehaviorDisplayText {
    return self
  }

  // Original Lingo body: erroralert
  // ```lingo
  // on ErrorAlert me, theError, data
  //   behaviorName = string(me)
  //   delete word 1 of behaviorName
  //   delete char -30001 of behaviorName
  //   delete char -30001 of behaviorName
  //   case theError of
  //     #invalidString:
  //       if the runMode = "Author" then
  //         Message = substituteStrings(me, "BEHAVIOR ERROR: Frame ^0, Sprite ^1" & RETURN & "Behavior ^2" & RETURN & RETURN & "The DisplayText_SetText handler could not treat the following as a string:" & RETURN & RETURN & "^3", ["^0": the frame, "^1": me.spriteNum, "^2": behaviorName, "^3": data])
  //         alert(Message)
  //       end if
  //     #invalidPoint:
  //       if the runMode = "Author" then
  //         Message = substituteStrings(me, "BEHAVIOR ERROR: Frame ^0, Sprite ^1" & RETURN & "Behavior ^2" & RETURN & RETURN & "The DisplayText_SetText handler could not treat the following as a point:" & RETURN & RETURN & "^3", ["^0": the frame, "^1": me.spriteNum, "^2": behaviorName, "^3": data])
  //       end if
  //   end case
  // end
  // ```
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

  // Original Lingo body: substitutestrings
  // ```lingo
  // on substituteStrings me, parentString, childStringList
  //   i = childStringList.count()
  //   repeat while i
  //     tempString = EMPTY
  //     dummyString = childStringList.getPropAt(i)
  //     replacement = childStringList[i]
  //     lengthAdjust = dummyString.char.count - 1
  //     repeat while 1
  //       position = offset(dummyString, parentString)
  //       if not position then
  //         parentString = tempString & parentString
  //         exit repeat
  //         next repeat
  //       end if
  //       if position <> 1 then
  //         tempString = tempString & parentString.char[1..position - 1]
  //       end if
  //       tempString = tempString & replacement
  //       delete me.char[1..position + lengthAdjust]
  //     end repeat
  //     i = i - 1
  //   end repeat
  //   return parentString
  // end
  // ```
  func substituteStrings(_ parentString: String, childStringList: PropList) -> String {
    var result = parentString
    for i in 1...max(1, childStringList.count) {
      guard i <= childStringList.count else { break }
      let (key, value) = childStringList.getPropAt(i)
      result = result.replacingOccurrences(of: key, with: value.asString ?? "")
    }
    return result
  }

  // Original Lingo body: isoktoattach
  // ```lingo
  // on isOKToAttach me, aSpriteType, aSpriteNum
  //   case aSpriteType of
  //     #graphic:
  //       return getPos([#field, #text], sprite(aSpriteNum).member.type) <> 0
  //     #script:
  //       return 0
  //   end case
  // end
  // ```
  func isOKToAttach(aSpriteType: String, aSpriteNum: Int) -> Bool {
    switch aSpriteType {
    case "graphic":
      // return true if sprite member type is field or text
      return false  // stub
    case "script":
      return false
    default:
      return false
    }
  }
}
