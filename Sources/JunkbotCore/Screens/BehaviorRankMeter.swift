// Translated from Lingo: behavior_rankMeter_code.ls

class BehaviorRankMeter: LingoObject, @unchecked Sendable {
    var spriteNum: Int = 0

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   if glob[#rankdata][#keys] < glob[#hof] then
    //   else
    //     barwidth = 125
    //     rank = glob[#rankdata][#rank]
    //     total = glob[#rankdata][#players]
    //     if rank = 0 then
    //       mybar = barwidth
    //     else
    //       ratio = total / rank
    //       mybar = barwidth - (barwidth / ratio)
    //     end if
    //     sprite(me.spriteNum).width = mybar
    //     if (the frameLabel = "levels") or (the frameLabel = "credits") then
    //       sprite(me.spriteNum).loc = point(497, 296)
    //     else
    //       if not voidp(glob[#master_obj]) then
    //         if not voidp(glob[#master_obj].Prop[#state]) then
    //           if glob[#master_obj].Prop[#state] = #hide then
    //             sprite(me.spriteNum).loc = point(1000, 1000)
    //           else
    //             sprite(me.spriteNum).loc = point(76, 335)
    //           end if
    //         else
    //           sprite(me.spriteNum).loc = point(1000, 1000)
    //         end if
    //       else
    //         sprite(me.spriteNum).loc = point(1000, 1000)
    //       end if
    //     end if
    //     member("rank_box1").text = string(glob[#rankdata][#rank])
    //     member("rank_box2").text = "out of " & string(glob[#rankdata][#players])
    //   end if
    // end
    // ```
    func beginSprite() {
        let rankdata = Glob.shared["rankdata"].asPropList!
        let rankKeys = rankdata["keys"].asInt!
        let hof = Glob.shared["hof"].asInt!
        if rankKeys < hof {
            // no-op
        } else {
            let barwidth = 125
            let rank = rankdata["rank"].asInt!
            let total = rankdata["players"].asInt!
            let mybar: Int
            if rank == 0 {
                mybar = barwidth
            } else {
                let ratio = Double(total) / Double(rank)
                mybar = barwidth - Int(Double(barwidth) / ratio)
            }
            sprite(spriteNum).width = mybar
            let frameLabel = theFrameLabel
            if frameLabel == "levels" || frameLabel == "credits" {
                sprite(spriteNum).loc = Point(x: 497, y: 296)
            } else {
                let masterObjLV = Glob.shared["master_obj"]
                if !masterObjLV.isVoid {
                    let masterObj = masterObjLV.asPropList
                    if let masterState = masterObj?["state"].asString {
                        if masterState == "hide" {
                            sprite(spriteNum).loc = Point(x: 1000, y: 1000)
                        } else {
                            sprite(spriteNum).loc = Point(x: 76, y: 335)
                        }
                    } else {
                        sprite(spriteNum).loc = Point(x: 1000, y: 1000)
                    }
                } else {
                    sprite(spriteNum).loc = Point(x: 1000, y: 1000)
                }
            }
            member("rank_box1")?.text = String(rank)
            member("rank_box2")?.text = "out of \(total)"
        }
    }
}
