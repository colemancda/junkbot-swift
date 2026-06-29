// Translated from Lingo: behavior_rankMeter_code.ls

class BehaviorRankMeter {
    var spriteNum: Int = 0

    func beginSprite() {
        let rankdata = glob["rankdata"] as! [String: Any]
        let rankKeys = rankdata["keys"] as! Int
        let hof = glob["hof"] as! Int
        if rankKeys < hof {
            // no-op
        } else {
            let barwidth = 125
            let rank = rankdata["rank"] as! Int
            let total = rankdata["players"] as! Int
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
                if let masterObj = glob["master_obj"] {
                    let masterProp = (masterObj as AnyObject).prop as? [String: Any]
                    if let masterState = masterProp?["state"] as? String {
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
            member("rank_box1").text = String(rank)
            member("rank_box2").text = "out of \(total)"
        }
    }
}
