// Translated from Lingo: parent_playfield manager.ls

class PlayfieldManager {
    var pf_size: [Int] = [0, 0]
    var pf_spacing: [Int] = [0, 0]
    var pf_scale: Int = 1
    var pf_grid: [Int] = [0, 0]
    var config: [String: Any] = [String: Any]()
    var info: [String: Any] = [String: Any]()
    var background: [String: Any]? = nil
    var decalz: Int = 10001
    var playfield: [[Int]] = []
    var partslist: [[String: Any]?] = []
    var bg_image: Any? = nil
    var current_level: String? = nil
    var spriteBuffer: [Sprite] = []

    init(_ conf: Any?) {
        var conf = conf
        if let confStr = conf as? String {
            let p = glob["config_manager"].parseParams(confStr)
            conf = p["playfield"]
        }
        setConfig(conf)
        for i in 200...999 {
            spriteBuffer.append(sprite(i))
        }
        background = ["backdrop": member("bkg1", "backgrounds") as Any, "decals": [Any]()]
        decalz = 10001
    }

    func leave() {
        current_level = toString()
        eraseAll()
    }

    func refresh() {
        eraseAll()
        if let cl = current_level {
            setPlayfield(cl)
        }
    }

    func setConfig(_ conf: Any?) {
        info = [String: Any]()
        guard let conf = conf as? [String: Any] else { return }
        config = conf
        pf_size = conf["size"] as? [Int] ?? [0, 0]
        pf_spacing = conf["spacing"] as? [Int] ?? [0, 0]
        pf_scale = conf["scale"] as? Int ?? 1
        pf_grid = [pf_spacing[0] * pf_scale, pf_spacing[1] * pf_scale]
        if playfield.isEmpty {
            playfield = []
        }
        // Extend playfield columns to pf_size[0]
        while playfield.count < pf_size[0] {
            playfield.append([])
        }
        // Extend each column to pf_size[1]
        for i in 0..<pf_size[0] {
            while playfield[i].count < pf_size[1] {
                playfield[i].append(0)
            }
        }
        if partslist.isEmpty {
            partslist = []
        }
    }

    func setInfo(_ i: [String: Any]) {
        guard i["title"] != nil, i["par"] != nil else { return }
        info = i
        if Int(String(describing: info["par"] ?? "")) == nil {
            info["par"] = 0
        }
    }

    func getInfo() -> [String: Any]? {
        return info.isEmpty ? nil : info
    }

    func toString() -> String {
        var out_partslist = [String]()
        var out_typelist = ["BLOCK01", "BLOCK02"]
        var out_colorlist = ["GRAY", "blue"]
        var type_map: [String: Int] = ["BLOCK01": 1, "BLOCK02": 2]
        var color_map: [String: Int] = ["GRAY": 1, "blue": 2]

        for part in partslist {
            guard let part = part else { continue }
            let partType = part["type"] as? String ?? ""
            let type_num: Int
            if let tn = type_map[partType] {
                type_num = tn
            } else {
                out_typelist.append(partType)
                type_map[partType] = out_typelist.count
                type_num = out_typelist.count
            }
            let color_num: Int
            if let partColor = part["color"] as? String {
                if let cn = color_map[partColor] {
                    color_num = cn
                } else {
                    out_colorlist.append(partColor)
                    color_map[partColor] = out_colorlist.count
                    color_num = out_colorlist.count
                }
            } else {
                color_num = 0
            }
            let state_name: String
            if let s = part["state"] as? String {
                state_name = s
            } else {
                state_name = "0"
            }
            let frame_num: Int = part["frame"] as? Int ?? 0
            let label_val: String
            if let lv = part["label"] as? String {
                label_val = lv
            } else {
                label_val = "0"
            }
            let pos = part["pos"] as? Point ?? Point(x: 0, y: 0)
            let part_text = "\(pos.x);\(pos.y);\(type_num);\(color_num);\(state_name);\(frame_num);\(label_val)"
            out_partslist.append(part_text)
        }

        var out_bglist: [String: Any]
        if background == nil {
            out_bglist = ["backdrop": "bkg1", "decals": [Any]()]
        } else {
            let backdropName = (background?["backdrop"] as? Member)?.name ?? "bkg1"
            out_bglist = ["backdrop": backdropName, "decals": [String]()]
            var decalStrings = [String]()
            if let decals = background?["decals"] as? [[String: Any]] {
                for d in decals {
                    let loc = d["loc"] as? Point ?? Point(x: 0, y: 0)
                    let mName = (d["member"] as? Member)?.name ?? ""
                    decalStrings.append("\(loc.x);\(loc.y);\(mName)")
                }
            }
            out_bglist["decals"] = decalStrings
        }

        return glob.config_manager.toString([
            "info": info,
            "background": out_bglist,
            "playfield": config,
            "partslist": ["types": out_typelist, "colors": out_colorlist, "parts": out_partslist]
        ])
    }

    func setPlayfield(_ pfinfo: Any, opt: Any? = nil) {
        playfield = []
        partslist = []
        setConfig(config)
        var pfinfo: [String: Any]
        if let pfStr = pfinfo as? String {
            pfinfo = glob.config_manager.parseParams(pfStr)
        } else {
            pfinfo = pfinfo as? [String: Any] ?? [String: Any]()
        }
        if let i = pfinfo["info"] {
            info = i as? [String: Any] ?? [String: Any]()
        }
        if pfinfo["background"] == nil {
            pfinfo["background"] = ["backdrop": "bkg1", "decals": [Any]()]
        }
        var bg: [String: Any] = ["decals": [Any]()]
        let bgSection = pfinfo["background"] as? [String: Any] ?? [String: Any]()
        bg["backdrop"] = member(bgSection["backdrop"] as? String ?? "", "backgrounds")
        var decalEntries = bgSection["decals"]
        if let decalStr = decalEntries as? String {
            decalEntries = [decalStr]
        }
        var bgDecals = [[String: Any]]()
        if let decalList = decalEntries as? [String] {
            for d in decalList {
                let parts = d.split(separator: ";")
                if parts.count >= 3, let x = Int(parts[0]), let y = Int(parts[1]) {
                    let mName = String(parts[2])
                    bgDecals.append([
                        "member": member(mName, "backgrounds") as Any,
                        "loc": Point(x: x, y: y) as Any
                    ])
                }
            }
        }
        bg["decals"] = bgDecals
        background = bg
        refreshBackground()

        var pf = pfinfo["partslist"] as? [String: Any] ?? [String: Any]()
        var partsData = pf["parts"]
        if partsData == nil || (partsData as? String) == "" {
            partsData = [String]()
        } else if let partsStr = partsData as? String {
            partsData = [partsStr]
        }
        let typeList = pf["types"] as? [String] ?? []
        let colorList = pf["colors"] as? [String] ?? []
        if let partsList = partsData as? [String] {
            for p in partsList {
                let items = p.split(separator: ";")
                guard items.count >= 7 else { continue }
                let part_pos_x = Int(items[0]) ?? 0
                let part_pos_y = Int(items[1]) ?? 0
                let part_typenum = Int(items[2]) ?? 0
                let part_colornum = Int(items[3]) ?? 0
                let part_statename = String(items[4])
                let part_framenum = Int(items[5]) ?? 0
                let part_labelval = String(items[6])
                let part_type = part_typenum > 0 && part_typenum <= typeList.count ? typeList[part_typenum - 1] : ""
                let part_color: String? = part_colornum == 0 ? nil : (part_colornum <= colorList.count ? colorList[part_colornum - 1] : nil)
                var part: [String: Any] = [
                    "pos": Point(x: part_pos_x, y: part_pos_y),
                    "type": part_type,
                    "color": part_color as Any
                ]
                if part_labelval != "0" {
                    part["label"] = part_labelval
                }
                if !part_statename.isEmpty && part_statename != "0" {
                    part["state"] = part_statename
                }
                if part_framenum != 0 {
                    part["frame"] = part_framenum
                }
                switch part_type {
                case "HAZ_SLICKFIRE", "HAZ_SLICKFAN":
                    let st = part["state"] as? String
                    if st != "off" && st != "on" {
                        part["state"] = "on"
                    }
                default:
                    break
                }
                placePiece(part)
            }
        }
        current_level = toString()
    }

    func makeGrid() {
        bg_image = nil // image(pf_size[0] * pf_grid[0], pf_size[1] * pf_grid[1], 16)
        // fill bg_image with rgb(190, 225, 190)
        // draw grid dots at rgb(128, 128, 128)
        // member("editor-playfield grid").image = bg_image
        // member("editor-playfield grid").regPoint = Point(x: 0, y: 0)
    }

    func getPos(_ L: Point) -> [[Any]]? {
        guard glob.EDITOR["playfield_sprite"] != nil else { return nil }
        let spriteLoc = glob.EDITOR.playfield_sprite.loc ?? Point(x: 0, y: 0)
        let px = (L.x - spriteLoc.x) / pf_grid[0]
        let py = (L.y - spriteLoc.y) / pf_grid[1]
        let l2x = ((px + 0) * pf_grid[0]) + spriteLoc.x
        let l2y = ((py + 1) * pf_grid[1]) + spriteLoc.y
        let gridX = px + 1
        let gridY = py + 1
        if gridX < 1 || gridY < 1 || gridX > pf_size[0] || gridY > pf_size[1] {
            return nil
        }
        return [[gridX, gridY], [Point(x: l2x, y: l2y)]]
    }

    func getLoc(_ arg: Any?) -> Point {
        var o = Point(x: 0, y: 0)
        let p: Point
        if let argDict = arg as? [String: Any] {
            p = argDict["pos"] as? Point ?? Point(x: 0, y: 0)
            if let po = argDict["pixelOffset"] as? Point {
                o = po
            }
        } else {
            p = arg as? Point ?? Point(x: 0, y: 0)
        }
        let spriteLoc = glob.EDITOR.playfield_sprite.loc ?? Point(x: 0, y: 0)
        return Point(
            x: ((p.x - 1) * pf_grid[0]) + spriteLoc.x + o.x,
            y: (p.y * pf_grid[1]) + spriteLoc.y + o.y
        )
    }

    func getPart(_ pos: Any?) -> [String: Any]? {
        guard let pos = pos as? [Int], pos.count >= 2 else { return nil }
        let x = pos[0] - 1, y = pos[1] - 1
        guard x >= 0, y >= 0, x < playfield.count, y < (playfield.first?.count ?? 0) else { return nil }
        let p = playfield[x][y]
        if p == 0 { return nil }
        return partslist[p - 1]
    }

    func checkFit(_ pos: Any?, _ typ: String) -> Bool {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pos = pos as? [Int], pos.count >= 2 else { return false }
        for d in sh {
            let tx = pos[0] + (d as? [Int])?[0] ?? 0
            let ty = pos[1] + (d as? [Int])?[1] ?? 0
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] { return false }
            if playfield[tx - 1][ty - 1] != 0 { return false }
        }
        return true
    }

    func checkFitOrGoal(_ pos: Any?, _ typ: String) -> Any {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pos = pos as? [Int] else { return false }
        var fit = true
        var goal: [String: Any]? = nil
        for d in sh {
            let tx = pos[0] + (d as? [Int])?[0] ?? 0
            let ty = pos[1] + (d as? [Int])?[1] ?? 0
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] { return false }
            let pnum = playfield[tx - 1][ty - 1]
            if pnum != 0 {
                let p = partslist[pnum - 1]
                if let p = p, goalP(p) {
                    goal = p
                    continue
                }
                return false
            }
        }
        if let goal = goal { return goal }
        return fit
    }

    func checkFitOrNonbrick(_ pos: Any?, _ typ: String) -> Any {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pos = pos as? [Int] else { return false }
        var fit = true
        var nonbrick: [String: Any]? = nil
        for d in sh {
            let tx = pos[0] + (d as? [Int])?[0] ?? 0
            let ty = pos[1] + (d as? [Int])?[1] ?? 0
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] { return false }
            let pnum = playfield[tx - 1][ty - 1]
            if pnum != 0 {
                let p = partslist[pnum - 1]
                if let p = p, !brickP(p) {
                    nonbrick = p
                    continue
                }
                return false
            }
        }
        if let nonbrick = nonbrick { return nonbrick }
        return fit
    }

    func checkFitOrMinifig(_ pos: Any?, _ typ: String) -> Any {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pos = pos as? [Int] else { return false }
        var fit = true
        var goal: [String: Any]? = nil
        for d in sh {
            let tx = pos[0] + (d as? [Int])?[0] ?? 0
            let ty = pos[1] + (d as? [Int])?[1] ?? 0
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] { return false }
            let pnum = playfield[tx - 1][ty - 1]
            if pnum != 0 {
                let p = partslist[pnum - 1]
                if let p = p, minifigP(p) {
                    goal = p
                    continue
                }
                return false
            }
        }
        if let goal = goal { return goal }
        return fit
    }

    func checkFitMiniFigHit(_ pos: Any?, _ typ: String) -> Bool {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pos = pos as? [Int] else { return false }
        var fit = true
        var goal: [String: Any]? = nil
        for d in sh {
            let tx = pos[0] + (d as? [Int])?[0] ?? 0
            let ty = pos[1] + (d as? [Int])?[1] ?? 0
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] {
                fit = false
                goal = nil
                break
            }
            let pnum = playfield[tx - 1][ty - 1]
            if pnum != 0 {
                let p = partslist[pnum - 1]
                if let p = p, minifigP(p) {
                    goal = p
                } else {
                    goal = nil
                }
                fit = false
                break
            }
        }
        if let goal = goal {
            glob.PLAYER["minifigHit"] = goal
        }
        return fit
    }

    func checkPlaceable(_ pos: Any?, _ typ: String) -> String {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pos = pos as? [Int] else { return "nofit" }
        var fit = true
        var edgetop = "free"
        var edgebottom = "free"
        outerLoop: for d in sh {
            let tx = pos[0] + (d as? [Int])?[0] ?? 0
            let ty = pos[1] + (d as? [Int])?[1] ?? 0
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] {
                fit = false
                break
            } else if playfield[tx - 1][ty - 1] != 0 {
                fit = false
                break
            }
            if ty > 1 {
                let above = playfield[tx - 1][ty - 2]
                if above != 0 {
                    if let abovePart = partslist[above - 1], brickP(abovePart) {
                        edgetop = "brick"
                    } else if let abovePart = partslist[above - 1], slickBrickP(abovePart) {
                        fit = false
                        break
                    }
                }
            }
            if ty == pf_size[1] {
                edgebottom = "bottom"
                continue
            }
            let below = playfield[tx - 1][ty]
            if below != 0 {
                if let belowPart = partslist[below - 1], brickP(belowPart) {
                    edgebottom = "brick"
                    continue
                }
                if let belowPart = partslist[below - 1], slickBrickP(belowPart) {
                    fit = false
                    break
                }
            }
        }
        if !fit { return "nofit" }
        if edgetop == "free" && (edgebottom == "free" || edgebottom == "bottom") { return "fit" }
        if edgebottom != "free" && edgetop == "free" { return "below" }
        if (edgebottom == "free" || edgebottom == "bottom") && edgetop != "free" { return "above" }
        return "nofit"
    }

    func checkFloor(_ pos: [Int], _ w: Int) -> Int {
        var n = 0
        for i in 0..<w {
            let x = pos[0] + i
            if x > 0 && x <= pf_size[0] {
                if pos[1] < pf_size[1] {
                    let pnum = playfield[x - 1][pos[1]]
                    if pnum != 0, let p = partslist[pnum - 1] {
                        n += (brickP(p) || slickBrickP(p)) ? 1 : 0
                    }
                    continue
                }
                n += 1
            }
        }
        return n
    }

    func placePiece(_ pos: Any?, _ typ: String? = nil, _ mem: Member? = nil, _ col: String? = nil, _ spr: Sprite? = nil) {
        var part: [String: Any]
        if let posDict = pos as? [String: Any] {
            part = posDict
        } else {
            part = ["pos": pos as Any, "type": typ as Any, "color": col as Any, "member": mem as Any, "sprite": spr as Any]
        }
        let partmembers = glob.legoparts_manager.getPieceMemberName(part)
        if part["sprite"] == nil {
            var sprites = [Sprite]()
            for _ in 0..<(partmembers as? [Any])?.count ?? 0 {
                if let s = getASprite() { sprites.append(s) }
            }
            part["sprite"] = sprites
        }
        partslist.append(part)
        let partnum = partslist.count
        let sh = glob.legoparts_manager.getPieceShape(part["type"] as? String ?? "")
        let partPos = part["pos"] as? Point ?? Point(x: 0, y: 0)
        for d in sh {
            let dx = (d as? [Int])?[0] ?? 0
            let dy = (d as? [Int])?[1] ?? 0
            let tx = partPos.x + dx
            let ty = partPos.y + dy
            if tx >= 1 && ty >= 1 && tx <= pf_size[0] && ty <= pf_size[1] {
                playfield[tx - 1][ty - 1] = partnum
            }
        }
        let sprites = part["sprite"] as? [Sprite] ?? []
        let memberNames = partmembers as? [String] ?? []
        for (si, s) in sprites.enumerated() {
            s.puppet = 1
            if si < memberNames.count { s.member = member(memberNames[si]) }
            s.width = (s.member?.width ?? 0) * pf_scale
            s.height = (s.member?.height ?? 0) * pf_scale
            s.loc = getLoc(part)
            s.visible = true
            s.ink = brickP(part) ? 8 : 36
            let shiftedPos = Point(x: partPos.x, y: partPos.y - si)
            s.locZ = posToLocZ(shiftedPos)
            s.blend = 100
            s.scriptInstanceList.append(PartClickBehavior(part))
        }
        if let behavior = part["behavior"] as? AnyObject {
            behavior.notify(["Start": 1])
        }
    }

    func posToLocZ(_ pos: Point) -> Int {
        return 100000 - (1000 * pos.y) + pos.x
    }

    func placePieceGroup(_ partgroup: [[String: Any]]) {
        for part in partgroup {
            placePiece(part)
        }
    }

    func erasePiece(_ pos: Any?, keepSprite: Bool = false) -> [String: Any]? {
        guard let pos = pos as? [Int], pos.count >= 2 else { return nil }
        let x = pos[0] - 1, y = pos[1] - 1
        guard x >= 0, y >= 0, x < playfield.count, y < (playfield.first?.count ?? 0) else { return nil }
        let partnum = playfield[x][y]
        if partnum == 0 { return nil }
        let part = partslist[partnum - 1]
        partslist[partnum - 1] = nil
        if let part = part {
            let basepos = part["pos"] as? Point ?? Point(x: 0, y: 0)
            let sh = glob.legoparts_manager.getPieceShape(part["type"] as? String ?? "")
            for d in sh {
                let dx = (d as? [Int])?[0] ?? 0
                let dy = (d as? [Int])?[1] ?? 0
                let tx = basepos.x + dx
                let ty = basepos.y + dy
                if tx >= 1 && ty >= 1 && tx <= pf_size[0] && ty <= pf_size[1] {
                    playfield[tx - 1][ty - 1] = 0
                }
            }
        }
        if !keepSprite {
            if let sprites = part?["sprite"] as? [Sprite] {
                for s in sprites {
                    s.loc = Point(x: -100, y: -100)
                    s.visible = false
                    s.scriptInstanceList = []
                    returnASprite(s)
                }
                var mutablePart = part
                mutablePart?["sprite"] = nil
            }
            if let auxSprites = part?["auxSprites"] as? [Sprite] {
                for s in auxSprites {
                    s.loc = Point(x: -100, y: -100)
                    s.visible = false
                    s.scriptInstanceList = []
                    returnASprite(s)
                }
                var mutablePart = part
                mutablePart?["auxSprites"] = [String: Any]()
            }
        }
        if let behavior = part?["behavior"] as? AnyObject {
            behavior.notify(["stop": 1])
        }
        return part
    }

    func erasePieceGroup(_ partgroup: [[String: Any]], keepSprites: Bool = false) -> [[String: Any]?] {
        var erasedPieces = [[String: Any]?]()
        for part in partgroup {
            if let pos = part["pos"] as? [Int] {
                erasedPieces.append(erasePiece(pos, keepSprite: keepSprites))
            }
        }
        return erasedPieces
    }

    func releasePieceSprite(_ p: inout [String: Any]) {
        if let s = p["sprite"] as? Sprite {
            s.loc = Point(x: -100, y: -100)
            s.visible = false
            returnASprite(s)
        }
        p["sprite"] = nil
    }

    func releasePieceGroupSprites(_ partgroup: inout [[String: Any]]) {
        for i in 0..<partgroup.count {
            releasePieceSprite(&partgroup[i])
        }
    }

    func eraseAll() {
        for part in partslist {
            if let part = part, let pos = part["pos"] as? [Int] {
                _ = erasePiece(pos)
            }
        }
        hideDecals()
    }

    func brickP(_ p: [String: Any]) -> Bool {
        return (p["type"] as? String ?? "").contains("BRICK")
    }

    func slickBrickP(_ p: [String: Any]) -> Bool {
        return (p["type"] as? String ?? "").contains("_SLICK")
    }

    func supportP(_ p: [String: Any]) -> Bool {
        return brickP(p) && (p["color"] as? String ?? "").contains("GRAY")
    }

    func goalP(_ p: [String: Any]) -> Bool {
        return (p["type"] as? String ?? "").contains("FLAG")
    }

    func minifigP(_ p: [String: Any]) -> Bool {
        return (p["type"] as? String ?? "").contains("MINIFIG")
    }

    func partNeighbors(_ p: [String: Any], dir: String? = nil, exclude: [String]? = nil) -> [[String: Any]] {
        let exclude = exclude ?? []
        var nei = [[String: Any]]()
        let sh = glob.legoparts_manager.getPieceShape(p["type"] as? String ?? "")
        let pPos = p["pos"] as? Point ?? Point(x: 0, y: 0)
        for d in sh {
            let dx = (d as? [Int])?[0] ?? 0
            let dy = (d as? [Int])?[1] ?? 0
            let pos = Point(x: pPos.x + dx, y: pPos.y + dy)
            // check above
            if dir != "down" && pos.y > 1 {
                let n = playfield[pos.x - 1][pos.y - 2]
                if n != 0, let nPart = partslist[n - 1] {
                    let nType = nPart["type"] as? String ?? ""
                    if !nPart.elementsEqual(p) && !nei.contains(where: { $0.elementsEqual(nPart) }) && !exclude.contains(nType) {
                        nei.append(nPart)
                    }
                }
            }
            // check below
            if dir != "UP" && pos.y < pf_size[1] {
                let n = playfield[pos.x - 1][pos.y]
                if n != 0, let nPart = partslist[n - 1] {
                    if !nPart.elementsEqual(p) && brickP(nPart) && !nei.contains(where: { $0.elementsEqual(nPart) }) {
                        nei.append(nPart)
                    }
                }
            }
        }
        return nei
    }

    func partConnectedGroup(_ p: [String: Any], group: [[String: Any]]? = nil) -> [[String: Any]] {
        var group = group ?? [p]
        for n in partNeighbors(p) {
            if group.contains(where: { $0.elementsEqual(n) }) { continue }
            group.append(n)
            if brickP(n) {
                group = partConnectedGroup(n, group: group)
            }
        }
        return group
    }

    func partSupported(_ p: [String: Any], group: [[String: Any]]? = nil, ignoregroup: [[String: Any]] = [], recurse: Int = 1) -> Any {
        if supportP(p) { return "supported" }
        if !brickP(p) { return "illegal" }
        var group = group ?? [p]
        for n in partNeighbors(p, dir: nil, exclude: ["HAZ_FLOAT"]) {
            if ignoregroup.contains(where: { $0.elementsEqual(n) }) { continue }
            if group.contains(where: { $0.elementsEqual(n) }) { continue }
            group.append(n)
            if brickP(n) {
                let result = partSupported(n, group: group, ignoregroup: ignoregroup, recurse: recurse + 1)
                if let s = result as? String, s == "supported" || s == "illegal" {
                    return result
                }
                if let g = result as? [[String: Any]] { group = g }
            }
        }
        return group
    }

    func findPieceGroup(_ pos: [Int], dir: String) -> [[String: Any]] {
        var pieceGroup = [[String: Any]]()
        var newGroup = [[String: Any]]()
        let x = pos[0] - 1, y = pos[1] - 1
        guard x >= 0, y >= 0, x < playfield.count, y < (playfield.first?.count ?? 0) else { return [] }
        let firstpartnum = playfield[x][y]
        if firstpartnum == 0 { return [] }
        guard let firstpart = partslist[firstpartnum - 1] else { return [] }
        if !brickP(firstpart) || supportP(firstpart) { return [] }
        newGroup.append(firstpart)
        var moreNeighbors = true
        while moreNeighbors {
            moreNeighbors = false
            var neighbors = [[String: Any]]()
            for p in newGroup {
                let newneighbors = partNeighbors(p, dir: dir, exclude: ["HAZ_FLOAT"])
                if newneighbors.isEmpty { continue }
                for n in newneighbors {
                    if !neighbors.contains(where: { $0.elementsEqual(n) }) {
                        neighbors.append(n)
                    }
                }
                moreNeighbors = true
            }
            for n in neighbors {
                if !brickP(n) || supportP(n) { return [] }
            }
            for p in newGroup {
                if !pieceGroup.contains(where: { $0.elementsEqual(p) }) {
                    pieceGroup.append(p)
                }
            }
            newGroup = []
            for n in neighbors {
                if !newGroup.contains(where: { $0.elementsEqual(n) }) {
                    newGroup.append(n)
                }
            }
        }
        for p in newGroup {
            if !pieceGroup.contains(where: { $0.elementsEqual(p) }) {
                pieceGroup.append(p)
            }
        }
        let oDir = dir == "UP" ? "down" : "UP"
        var newpiecegroup = [[String: Any]]()
        for p in pieceGroup {
            for n in partNeighbors(p, dir: oDir) {
                if pieceGroup.contains(where: { $0.elementsEqual(n) }) { continue }
                let result = partSupported(n, ignoregroup: pieceGroup)
                if let s = result as? String {
                    if s == "supported" { continue }
                    if s == "illegal" { return [] }
                }
                if let unsupportedGroup = result as? [[String: Any]] {
                    for u in unsupportedGroup {
                        if !brickP(u) { return [] }
                        if !newpiecegroup.contains(where: { $0.elementsEqual(u) }) {
                            newpiecegroup.append(u)
                        }
                    }
                }
            }
        }
        for np in newpiecegroup {
            if !pieceGroup.contains(where: { $0.elementsEqual(np) }) {
                pieceGroup.append(np)
            }
        }
        return pieceGroup
    }

    func getPartsByType(_ typelist: Any) -> [[String: Any]] {
        var tlist = typelist as? [String] ?? []
        if let single = typelist as? String { tlist = [single] }
        var plist = [[String: Any]]()
        for p in partslist {
            guard let p = p else { continue }
            let pType = p["type"] as? String ?? ""
            for t in tlist {
                if pType == t { plist.append(p) }
            }
        }
        return plist
    }

    func getPartsByLabel(_ labelList: Any) -> [[String: Any]] {
        var llist = labelList as? [String] ?? []
        if let single = labelList as? String { llist = [single] }
        var plist = [[String: Any]]()
        for p in partslist {
            guard let p = p, let plabel = p["label"] as? String else { continue }
            for l in llist {
                if plabel == l { plist.append(p) }
            }
        }
        return plist
    }

    func setBackdrop(_ mem: Any) {
        background?["backdrop"] = mem
        refreshBackground()
    }

    func placeDecal(_ d: [String: Any]) {
        var decal = d
        guard let s = getASprite() else { return }
        decal["sprite"] = s
        s.member = decal["member"] as? Member
        if let m = decal["member"] as? Member {
            s.rect = m.rect
        }
        s.loc = decal["loc"] as? Point ?? Point(x: 0, y: 0)
        s.locZ = decalz
        decalz += 1
        s.blend = 100
        s.visible = true
        s.ink = 36
        var decals = background?["decals"] as? [[String: Any]] ?? []
        decals.append(decal)
        background?["decals"] = decals
    }

    func eraseDecal(_ L: Point) -> [String: Any]? {
        guard background != nil, var decals = background?["decals"] as? [[String: Any]] else { return nil }
        for i in stride(from: decals.count - 1, through: 0, by: -1) {
            let decal = decals[i]
            guard let m = decal["member"] as? Member,
                  let loc = decal["loc"] as? Point else { continue }
            let r = Rect(
                x: loc.x - (m.regPoint?.x ?? 0),
                y: loc.y - (m.regPoint?.y ?? 0),
                width: m.width,
                height: m.height
            )
            if r.contains(L) {
                if let s = decal["sprite"] as? Sprite {
                    s.loc = Point(x: -100, y: -100)
                    s.member = nil
                    returnASprite(s)
                }
                let removed = decals.remove(at: i)
                background?["decals"] = decals
                return removed
            }
        }
        return nil
    }

    func hideDecals() {
        guard background != nil, var decals = background?["decals"] as? [[String: Any]] else { return }
        for i in 0..<decals.count {
            if let s = decals[i]["sprite"] as? Sprite {
                s.loc = Point(x: -100, y: -100)
                s.member = nil
                returnASprite(s)
                decals[i]["sprite"] = nil
            }
        }
        background?["decals"] = decals
    }

    func refreshBackground() {
        glob.EDITOR.playfield_sprite.member = background?["backdrop"] as? Member
        var z = 10001
        guard var decals = background?["decals"] as? [[String: Any]] else { return }
        for i in 0..<decals.count {
            z += 1
            if decals[i]["sprite"] == nil {
                decals[i]["sprite"] = getASprite()
            }
            if let s = decals[i]["sprite"] as? Sprite {
                s.member = decals[i]["member"] as? Member
                if let m = decals[i]["member"] as? Member {
                    s.rect = m.rect
                }
                s.loc = decals[i]["loc"] as? Point ?? Point(x: 0, y: 0)
                s.locZ = z
                s.blend = 100
                s.visible = true
                s.ink = 36
            }
        }
        background?["decals"] = decals
        decalz = z + 1
    }

    func getASprite() -> Sprite? {
        if spriteBuffer.isEmpty { return nil }
        let s = spriteBuffer.removeFirst()
        s.puppet = 1
        return s
    }

    func returnASprite(_ s: Sprite) {
        s.scriptInstanceList = []
        spriteBuffer.append(s)
    }
}

// Helper: compare two [String: Any] dicts by identity (object identity not available for value types;
// this stub is used where Lingo would compare propList references)
private func == (lhs: [String: Any], rhs: [String: Any]) -> Bool {
    // Stub — real implementation would compare by reference or key identity
    return false
}

extension Dictionary where Key == String {
    func elementsEqual(_ other: [String: Any]) -> Bool {
        // Stub identity comparison
        return false
    }
}
