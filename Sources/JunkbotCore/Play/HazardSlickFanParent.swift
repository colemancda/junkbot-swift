// Translated from Lingo: parent_hazard slick fan parent.ls

public class HazardSlickFanParent: LingoObject, @unchecked Sendable {
    public var playfield_manager: LV = .void
    public var play_manager: PlayManager? = nil
    public var part: PropList
    public var myWidth: Int = 2
    public var last_step: Int = 0
    public var switch_: Int = 0  // 'switch' is a Swift keyword, renamed to switch_
    public var airjet_cycle: Int = 1
    public var partloc: Point = Point()
    public var top_locz: LV = .void
    public var dir: LV = .void

    // Original Lingo body: new
    // ```lingo
    // on new me, p
    //   part = p
    //   part[#behavior] = me
    //   play_manager = glob.PLAYER.play_manager
    //   playfield_manager = play_manager.playfield_manager
    //   partloc = part.sprite[1].loc
    //   myWidth = 2
    //   last_step = the ticks
    //   switch = 0
    //   airjet_cycle = random(7)
    //   top_locz = playfield_manager.posToLocZ(point(50, 1))
    //   return me
    // end
    // ```
    public init(_ p: PropList) {
        super.init()
        part = p
        // part["behavior"] = self -- set by caller
        play_manager = nil // Glob.shared.PLAYER.play_manager
        playfield_manager = .void // play_manager.playfield_manager
        // partloc = part.sprite[1].loc -- stub
        myWidth = 2
        last_step = currentTicks
        switch_ = 0
        airjet_cycle = lingoRandom(7)
        // top_locz = playfield_manager.posToLocZ(point(50, 1)) -- stub
    }

    // Original Lingo body: done
    // ```lingo
    // on done me
    //   play_manager.actorDone(me)
    // end
    // ```
    public func done() {
        if let pm = play_manager { pm.actorDone(self) }
    }

    // Original Lingo body: notify
    // ```lingo
    // on notify me, notes
    //   if notes[#destroyed] = 1 then
    //     me.done()
    //   else
    //     if notes[#pos] <> VOID then
    //       part.pos = notes[#pos]
    //     else
    //       if not voidp(notes[#switch]) then
    //         part.state = notes[#switch]
    //         me.stepAnim()
    //         me.updatePart()
    //       end if
    //     end if
    //   end if
    // end
    // ```
    public func notify(_ notes: PropList) {
        if let destroyed = notes["destroyed"].asInt, destroyed == 1 {
            done()
        } else if !notes["pos"].isVoid {
            part["pos"] = notes["pos"]
        } else if !notes["switch"].isVoid {
            part["state"] = notes["switch"]
            stepAnim()
            updatePart()
        }
    }

    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   me.stepAnim()
    //   me.updatePart()
    //   me.checkMiniFig()
    // end
    // ```
    public func stepFrame() {
        stepAnim()
        updatePart()
        checkMiniFig()
    }

    // Original Lingo body: stepanim
    // ```lingo
    // on stepAnim me
    //   if part.state = #on then
    //     part.frame = (part.frame mod 4) + 1
    //   else
    //     part.frame = 1
    //   end if
    // end
    // ```
    public func stepAnim() {
        let state = part["state"].asString ?? ""
        if state == "#on" {
            let frame = part["frame"].asInt ?? 1
            part["frame"] = .int((frame % 4) + 1)
        } else {
            part["frame"] = .int(1)
        }
    }

    // Original Lingo body: checkminifig
    // ```lingo
    // on checkMiniFig me
    //   y = -1
    //   gotMinifig = 0
    //   airjet_height = [0, 0]
    //   if part.state = #on then
    //     repeat while 1
    //       fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, y), #BRICK_01)
    //       case fig of
    //         0:
    //           exit repeat
    //         1:
    //         otherwise:
    //           gotMinifig = fig
    //           exit repeat
    //       end case
    //       y = y - 1
    //       airjet_height[1] = airjet_height[1] + 1
    //     end repeat
    //     y = -1
    //     repeat while 1
    //       fig = playfield_manager.checkFitOrMinifig(part.pos + point(2, y), #BRICK_01)
    //       case fig of
    //         0:
    //           exit repeat
    //         1:
    //         otherwise:
    //           gotMinifig = fig
    //           exit repeat
    //       end case
    //       y = y - 1
    //       airjet_height[2] = airjet_height[2] + 1
    //     end repeat
    //     if gotMinifig <> 0 then
    //       if not switch then
    //         SndSFX("fan")
    //         switch = 1
    //       end if
    //       gotMinifig.behavior.notify([#FAN: part])
    //     else
    //       switch = 0
    //     end if
    //     airjet_cycle = airjet_cycle + 1
    //     if airjet_cycle > 7 then
    //       airjet_cycle = 1
    //     end if
    //     sprs = [playfield_manager.getASprite(), playfield_manager.getASprite()]
    //     part[#auxSprites] = [:]
    //     part.auxSprites[#airjet1] = sprs[1]
    //     part.auxSprites[#airjet2] = sprs[2]
    //     repeat with i = 1 to sprs.count
    //       s = sprs[i]
    //       s.ink = 8
    //       if airjet_height[i] > 0 then
    //         s.visible = 1
    //         s.member = member("fanAir_" & airjet_height[i] & "_" & airjet_cycle)
    //         s.rect = s.member.rect
    //       else
    //         s.visible = 0
    //       end if
    //       s.loc = partloc + point((i * 15) + 2, -19)
    //       s.locZ = top_locz
    //     end repeat
    //   end if
    // end
    // ```
    public func checkMiniFig() {
        let state = part["state"].asString ?? ""
        var gotMinifig: LV = .void
        var airjet_height = [0, 0]
        if state == "#on" {
            var y = -1
            while true {
                // fig = playfield_manager.checkFitOrMinifig(part.pos + point(1, y), "#BRICK_01") -- stub
                let fig: LV = .int(1) // stub
                if let figInt = fig.asInt, figInt == 0 { break }
                if fig.isPropList {
                    gotMinifig = fig
                    break
                }
                y -= 1
                airjet_height[0] += 1
            }
            y = -1
            while true {
                // fig = playfield_manager.checkFitOrMinifig(part.pos + point(2, y), "#BRICK_01") -- stub
                let fig: LV = .int(1) // stub
                if let figInt = fig.asInt, figInt == 0 { break }
                if fig.isPropList {
                    gotMinifig = fig
                    break
                }
                y -= 1
                airjet_height[1] += 1
            }
            if gotMinifig.isPropList {
                if switch_ == 0 {
                    SndSFX("fan")
                    switch_ = 1
                }
                // gotMinifig.asPropList!.behavior.notify(["FAN": part]) -- stub
            } else {
                switch_ = 0
            }
            airjet_cycle += 1
            if airjet_cycle > 7 {
                airjet_cycle = 1
            }
            // Render airjet sprites -- stub
            for i in 0..<2 {
                if airjet_height[i] > 0 {
                    // s.visible = 1; s.member = member("fanAir_\(airjet_height[i])_\(airjet_cycle)") -- stub
                    // s.loc = partloc + point((i+1)*15 + 2, -19); s.locZ = top_locz -- stub
                } else {
                    // s.visible = 0 -- stub
                }
                _ = i
            }
        }
    }

    // Original Lingo body: updatepart
    // ```lingo
    // on updatePart me
    //   playfield_manager.erasePiece(part.pos)
    //   playfield_manager.placePiece(part)
    // end
    // ```
    public func updatePart() {
        // playfield_manager.erasePiece(part.pos) -- stub
        // playfield_manager.placePiece(part) -- stub
    }
}
