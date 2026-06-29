// Translated from Lingo: parent_playfield manager.ls

class PlayfieldManager {
    var pf_size: [Int] = [0, 0]
    var pf_spacing: [Int] = [0, 0]
    var pf_scale: Int = 1
    var pf_grid: [Int] = [0, 0]
    var config: PropList = PropList()
    var info: PropList = PropList()
    var background: PropList? = nil
    var decalz: Int = 10001
    var playfield: [[Int]] = []
    var partslist: [PropList?] = []
    var bg_image: LV = .void
    var current_level: String? = nil
    var spriteBuffer: [LingoSprite] = []

    init(_ conf: LV) {
        var resolvedConf: LV = conf
        if let confStr = conf.asString {
            let p = glob["config_manager"].parseParams(confStr)
            resolvedConf = p["playfield"]
        }
        setConfig(resolvedConf)
        for i in 200...999 {
            spriteBuffer.append(sprite(i))
        }
        let bg = PropList()
        bg["backdrop"] = .object(member("bkg1", "backgrounds"))
        bg["decals"] = .list(LingoList())
        background = bg
        decalz = 10001
    }

    func leave() {
        current_level = toString()
        eraseAll()
    }

    func refresh() {
        eraseAll()
        if let cl = current_level {
            setPlayfield(.string(cl))
        }
    }

    func setConfig(_ conf: LV) {
        info = PropList()
        guard let confPL = conf.asPropList else { return }
        config = confPL
        if let sizeList = confPL["size"].asList {
            pf_size = [sizeList[1].asInt ?? 0, sizeList[2].asInt ?? 0]
        }
        if let spacingList = confPL["spacing"].asList {
            pf_spacing = [spacingList[1].asInt ?? 0, spacingList[2].asInt ?? 0]
        }
        pf_scale = confPL["scale"].asInt ?? 1
        pf_grid = [pf_spacing[0] * pf_scale, pf_spacing[1] * pf_scale]
        if playfield.isEmpty {
            playfield = []
        }
        while playfield.count < pf_size[0] {
            playfield.append([])
        }
        for i in 0..<pf_size[0] {
            while playfield[i].count < pf_size[1] {
                playfield[i].append(0)
            }
        }
        if partslist.isEmpty {
            partslist = []
        }
    }

    func setInfo(_ i: PropList) {
        guard !i["title"].isVoid, !i["par"].isVoid else { return }
        info = i
        if Int(info["par"].asString ?? "") == nil {
            info["par"] = .int(0)
        }
    }

    func getInfo() -> PropList? {
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
            let partType = part["type"].asString ?? ""
            let type_num: Int
            if let tn = type_map[partType] {
                type_num = tn
            } else {
                out_typelist.append(partType)
                type_map[partType] = out_typelist.count
                type_num = out_typelist.count
            }
            let color_num: Int
            if let partColor = part["color"].asString {
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
            if let s = part["state"].asString {
                state_name = s
            } else {
                state_name = "0"
            }
            let frame_num: Int = part["frame"].asInt ?? 0
            let label_val: String
            if let lv = part["label"].asString {
                label_val = lv
            } else {
                label_val = "0"
            }
            let pos = part["pos"].asPoint ?? Point(x: 0, y: 0)
            let part_text = "\(pos.x);\(pos.y);\(type_num);\(color_num);\(state_name);\(frame_num);\(label_val)"
            out_partslist.append(part_text)
        }

        let out_bglist = PropList()
        if background == nil {
            out_bglist["backdrop"] = .string("bkg1")
            out_bglist["decals"] = .list(LingoList())
        } else {
            let backdropName = (background?["backdrop"].asObject() as? LingoMember)?.name ?? "bkg1"
            out_bglist["backdrop"] = .string(backdropName)
            let decalStrings = LingoList()
            if let decalsList = background?["decals"].asList {
                for i in 1...max(1, decalsList.count) {
                    if let d = decalsList[i].asPropList {
                        let loc = d["loc"].asPoint ?? Point(x: 0, y: 0)
                        let mName = (d["member"].asObject() as? LingoMember)?.name ?? ""
                        decalStrings.add(.string("\(loc.x);\(loc.y);\(mName)"))
                    }
                }
            }
            out_bglist["decals"] = .list(decalStrings)
        }

        let typesList = LingoList()
        for t in out_typelist { typesList.add(.string(t)) }
        let colorsList = LingoList()
        for c in out_colorlist { colorsList.add(.string(c)) }
        let partsList = LingoList()
        for p in out_partslist { partsList.add(.string(p)) }
        let partslistPL = PropList()
        partslistPL["types"] = .list(typesList)
        partslistPL["colors"] = .list(colorsList)
        partslistPL["parts"] = .list(partsList)

        let wrapper = PropList()
        wrapper["info"] = .propList(info)
        wrapper["background"] = .propList(out_bglist)
        wrapper["playfield"] = .propList(config)
        wrapper["partslist"] = .propList(partslistPL)
        return glob.config_manager.toString(wrapper)
    }

    func setPlayfield(_ pfinfo: LV, opt: LV = .void) {
        playfield = []
        partslist = []
        setConfig(.propList(config))
        var pfinfoDict: PropList
        if let pfStr = pfinfo.asString {
            pfinfoDict = glob.config_manager.parseParams(pfStr)
        } else if let pl = pfinfo.asPropList {
            pfinfoDict = pl
        } else {
            pfinfoDict = PropList()
        }
        if let i = pfinfoDict["info"].asPropList {
            info = i
        }
        if pfinfoDict["background"].isVoid {
            let defaultBg = PropList()
            defaultBg["backdrop"] = .string("bkg1")
            defaultBg["decals"] = .list(LingoList())
            pfinfoDict["background"] = .propList(defaultBg)
        }
        let bg = PropList()
        bg["decals"] = .list(LingoList())
        let bgSection = pfinfoDict["background"].asPropList ?? PropList()
        bg["backdrop"] = .object(member(bgSection["backdrop"].asString ?? "", "backgrounds"))
        var decalEntries = bgSection["decals"]
        if let decalStr = decalEntries.asString {
            let dl = LingoList()
            dl.add(.string(decalStr))
            decalEntries = .list(dl)
        }
        let bgDecalsList = LingoList()
        if let decalList = decalEntries.asList {
            for i in 1...max(1, decalList.count) {
                if let dStr = decalList[i].asString {
                    let parts = dStr.split(separator: ";")
                    if parts.count >= 3, let x = Int(parts[0]), let y = Int(parts[1]) {
                        let mName = String(parts[2])
                        let decalPL = PropList()
                        decalPL["member"] = .object(member(mName, "backgrounds"))
                        decalPL["loc"] = .point(x: x, y: y)
                        bgDecalsList.add(.propList(decalPL))
                    }
                }
            }
        }
        bg["decals"] = .list(bgDecalsList)
        background = bg
        refreshBackground()

        let pf = pfinfoDict["partslist"].asPropList ?? PropList()
        var partsData = pf["parts"]
        if partsData.isVoid || partsData.asString == "" {
            partsData = .list(LingoList())
        } else if let partsStr = partsData.asString {
            let pl = LingoList()
            pl.add(.string(partsStr))
            partsData = .list(pl)
        }
        let typeListLV = pf["types"].asList
        let colorListLV = pf["colors"].asList
        var typeList = [String]()
        var colorList = [String]()
        if let tl = typeListLV {
            for i in 1...max(1, tl.count) { if let s = tl[i].asString { typeList.append(s) } }
        }
        if let cl = colorListLV {
            for i in 1...max(1, cl.count) { if let s = cl[i].asString { colorList.append(s) } }
        }
        if let partsList = partsData.asList {
            for i in 1...max(1, partsList.count) {
                guard let p = partsList[i].asString else { continue }
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
                let part = PropList()
                part["pos"] = .point(x: part_pos_x, y: part_pos_y)
                part["type"] = .string(part_type)
                if let pc = part_color {
                    part["color"] = .string(pc)
                }
                if part_labelval != "0" {
                    part["label"] = .string(part_labelval)
                }
                if !part_statename.isEmpty && part_statename != "0" {
                    part["state"] = .string(part_statename)
                }
                if part_framenum != 0 {
                    part["frame"] = .int(part_framenum)
                }
                switch part_type {
                case "HAZ_SLICKFIRE", "HAZ_SLICKFAN":
                    let st = part["state"].asString
                    if st != "off" && st != "on" {
                        part["state"] = .string("on")
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
        bg_image = .void // image(pf_size[0] * pf_grid[0], pf_size[1] * pf_grid[1], 16)
        // fill bg_image with rgb(190, 225, 190)
        // draw grid dots at rgb(128, 128, 128)
        // member("editor-playfield grid").image = bg_image
        // member("editor-playfield grid").regPoint = Point(x: 0, y: 0)
    }

    func getPos(_ L: Point) -> [LV]? {
        guard !glob.EDITOR["playfield_sprite"].isVoid else { return nil }
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
        return [.point(x: gridX, y: gridY), .point(x: l2x, y: l2y)]
    }

    func getLoc(_ arg: LV) -> Point {
        var o = Point(x: 0, y: 0)
        let p: Point
        if let argDict = arg.asPropList {
            p = argDict["pos"].asPoint ?? Point(x: 0, y: 0)
            if let po = argDict["pixelOffset"].asPoint {
                o = po
            }
        } else {
            p = arg.asPoint ?? Point(x: 0, y: 0)
        }
        let spriteLoc = glob.EDITOR.playfield_sprite.loc ?? Point(x: 0, y: 0)
        return Point(
            x: ((p.x - 1) * pf_grid[0]) + spriteLoc.x + o.x,
            y: (p.y * pf_grid[1]) + spriteLoc.y + o.y
        )
    }

    func getPart(_ pos: LV) -> PropList? {
        guard let pt = pos.asPoint else { return nil }
        let x = pt.x - 1, y = pt.y - 1
        guard x >= 0, y >= 0, x < playfield.count, y < (playfield.first?.count ?? 0) else { return nil }
        let p = playfield[x][y]
        if p == 0 { return nil }
        return partslist[p - 1]
    }

    func checkFit(_ pos: LV, _ typ: String) -> Bool {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pt = pos.asPoint else { return false }
        for d in sh {
            let dx = d.asPoint?.x ?? 0
            let dy = d.asPoint?.y ?? 0
            let tx = pt.x + dx
            let ty = pt.y + dy
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] { return false }
            if playfield[tx - 1][ty - 1] != 0 { return false }
        }
        return true
    }

    func checkFitOrGoal(_ pos: LV, _ typ: String) -> LV {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pt = pos.asPoint else { return .int(0) }
        var goal: PropList? = nil
        for d in sh {
            let dx = d.asPoint?.x ?? 0
            let dy = d.asPoint?.y ?? 0
            let tx = pt.x + dx
            let ty = pt.y + dy
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] { return .int(0) }
            let pnum = playfield[tx - 1][ty - 1]
            if pnum != 0 {
                let p = partslist[pnum - 1]
                if let p = p, goalP(p) {
                    goal = p
                    continue
                }
                return .int(0)
            }
        }
        if let goal = goal { return .propList(goal) }
        return .int(1)
    }

    func checkFitOrNonbrick(_ pos: LV, _ typ: String) -> LV {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pt = pos.asPoint else { return .int(0) }
        var nonbrick: PropList? = nil
        for d in sh {
            let dx = d.asPoint?.x ?? 0
            let dy = d.asPoint?.y ?? 0
            let tx = pt.x + dx
            let ty = pt.y + dy
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] { return .int(0) }
            let pnum = playfield[tx - 1][ty - 1]
            if pnum != 0 {
                let p = partslist[pnum - 1]
                if let p = p, !brickP(p) {
                    nonbrick = p
                    continue
                }
                return .int(0)
            }
        }
        if let nonbrick = nonbrick { return .propList(nonbrick) }
        return .int(1)
    }

    func checkFitOrMinifig(_ pos: LV, _ typ: String) -> LV {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pt = pos.asPoint else { return .int(0) }
        var goal: PropList? = nil
        for d in sh {
            let dx = d.asPoint?.x ?? 0
            let dy = d.asPoint?.y ?? 0
            let tx = pt.x + dx
            let ty = pt.y + dy
            if tx < 1 || ty < 1 || tx > pf_size[0] || ty > pf_size[1] { return .int(0) }
            let pnum = playfield[tx - 1][ty - 1]
            if pnum != 0 {
                let p = partslist[pnum - 1]
                if let p = p, minifigP(p) {
                    goal = p
                    continue
                }
                return .int(0)
            }
        }
        if let goal = goal { return .propList(goal) }
        return .int(1)
    }

    func checkFitMiniFigHit(_ pos: LV, _ typ: String) -> Bool {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pt = pos.asPoint else { return false }
        var fit = true
        var goal: PropList? = nil
        for d in sh {
            let dx = d.asPoint?.x ?? 0
            let dy = d.asPoint?.y ?? 0
            let tx = pt.x + dx
            let ty = pt.y + dy
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
            glob.PLAYER["minifigHit"] = .propList(goal)
        }
        return fit
    }

    func checkPlaceable(_ pos: LV, _ typ: String) -> String {
        let sh = glob.legoparts_manager.getPieceShape(typ)
        guard let pt = pos.asPoint else { return "nofit" }
        var fit = true
        var edgetop = "free"
        var edgebottom = "free"
        outerLoop: for d in sh {
            let dx = d.asPoint?.x ?? 0
            let dy = d.asPoint?.y ?? 0
            let tx = pt.x + dx
            let ty = pt.y + dy
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
                        break outerLoop
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
                    break outerLoop
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

    func placePiece(_ part: PropList) {
        let partmembers = glob.legoparts_manager.getPieceMemberName(part)
        if part["sprite"].isVoid {
            let sprites = LingoList()
            let memberCount = partmembers.asList?.count ?? 0
            for _ in 0..<memberCount {
                if let s = getASprite() { sprites.add(.object(s)) }
            }
            part["sprite"] = .list(sprites)
        }
        partslist.append(part)
        let partnum = partslist.count
        let sh = glob.legoparts_manager.getPieceShape(part["type"].asString ?? "")
        let partPos = part["pos"].asPoint ?? Point(x: 0, y: 0)
        for d in sh {
            let dx = d.asPoint?.x ?? 0
            let dy = d.asPoint?.y ?? 0
            let tx = partPos.x + dx
            let ty = partPos.y + dy
            if tx >= 1 && ty >= 1 && tx <= pf_size[0] && ty <= pf_size[1] {
                playfield[tx - 1][ty - 1] = partnum
            }
        }
        if let spriteList = part["sprite"].asList,
           let memberList = partmembers.asList {
            for si in 1...max(1, spriteList.count) {
                guard let s = spriteList[si].asObject() as? LingoSprite else { continue }
                s.puppet = 1
                if si <= memberList.count, let mName = memberList[si].asString {
                    s.member = member(mName)
                }
                s.width = (s.member?.width ?? 0) * pf_scale
                s.height = (s.member?.height ?? 0) * pf_scale
                s.loc = getLoc(.propList(part))
                s.visible = true
                s.ink = brickP(part) ? 8 : 36
                let shiftedPos = Point(x: partPos.x, y: partPos.y - (si - 1))
                s.locZ = posToLocZ(shiftedPos)
                s.blend = 100
                s.scriptInstanceList.append(PartClickBehavior(part))
            }
        }
        if let behavior = part["behavior"].asObject() {
            behavior.notify(["Start": 1])
        }
    }

    func posToLocZ(_ pos: Point) -> Int {
        return 100000 - (1000 * pos.y) + pos.x
    }

    func placePieceGroup(_ partgroup: [PropList]) {
        for part in partgroup {
            placePiece(part)
        }
    }

    func erasePiece(_ pos: LV, keepSprite: Bool = false) -> PropList? {
        guard let pt = pos.asPoint else { return nil }
        let x = pt.x - 1, y = pt.y - 1
        guard x >= 0, y >= 0, x < playfield.count, y < (playfield.first?.count ?? 0) else { return nil }
        let partnum = playfield[x][y]
        if partnum == 0 { return nil }
        let part = partslist[partnum - 1]
        partslist[partnum - 1] = nil
        if let part = part {
            let basepos = part["pos"].asPoint ?? Point(x: 0, y: 0)
            let sh = glob.legoparts_manager.getPieceShape(part["type"].asString ?? "")
            for d in sh {
                let dx = d.asPoint?.x ?? 0
                let dy = d.asPoint?.y ?? 0
                let tx = basepos.x + dx
                let ty = basepos.y + dy
                if tx >= 1 && ty >= 1 && tx <= pf_size[0] && ty <= pf_size[1] {
                    playfield[tx - 1][ty - 1] = 0
                }
            }
        }
        if !keepSprite {
            if let spriteList = part?["sprite"].asList {
                for i in 1...max(1, spriteList.count) {
                    if let s = spriteList[i].asObject() as? LingoSprite {
                        s.loc = Point(x: -100, y: -100)
                        s.visible = false
                        s.scriptInstanceList = []
                        returnASprite(s)
                    }
                }
                part?["sprite"] = .void
            }
            if let auxSpriteList = part?["auxSprites"].asList {
                for i in 1...max(1, auxSpriteList.count) {
                    if let s = auxSpriteList[i].asObject() as? LingoSprite {
                        s.loc = Point(x: -100, y: -100)
                        s.visible = false
                        s.scriptInstanceList = []
                        returnASprite(s)
                    }
                }
                part?["auxSprites"] = .void
            }
        }
        if let behavior = part?["behavior"].asObject() {
            behavior.notify(["stop": 1])
        }
        return part
    }

    func erasePieceGroup(_ partgroup: [PropList], keepSprites: Bool = false) -> [PropList?] {
        var erasedPieces = [PropList?]()
        for part in partgroup {
            erasedPieces.append(erasePiece(part["pos"], keepSprite: keepSprites))
        }
        return erasedPieces
    }

    func releasePieceSprite(_ p: PropList) {
        if let s = p["sprite"].asObject() as? LingoSprite {
            s.loc = Point(x: -100, y: -100)
            s.visible = false
            returnASprite(s)
        }
        p["sprite"] = .void
    }

    func releasePieceGroupSprites(_ partgroup: [PropList]) {
        for p in partgroup {
            releasePieceSprite(p)
        }
    }

    func eraseAll() {
        for part in partslist {
            if let part = part {
                _ = erasePiece(part["pos"])
            }
        }
        hideDecals()
    }

    func brickP(_ p: PropList) -> Bool {
        return (p["type"].asString ?? "").contains("BRICK")
    }

    func slickBrickP(_ p: PropList) -> Bool {
        return (p["type"].asString ?? "").contains("_SLICK")
    }

    func supportP(_ p: PropList) -> Bool {
        return brickP(p) && (p["color"].asString ?? "").contains("GRAY")
    }

    func goalP(_ p: PropList) -> Bool {
        return (p["type"].asString ?? "").contains("FLAG")
    }

    func minifigP(_ p: PropList) -> Bool {
        return (p["type"].asString ?? "").contains("MINIFIG")
    }

    func partNeighbors(_ p: PropList, dir: String? = nil, exclude: [String]? = nil) -> [PropList] {
        let exclude = exclude ?? []
        var nei = [PropList]()
        let sh = glob.legoparts_manager.getPieceShape(p["type"].asString ?? "")
        let pPos = p["pos"].asPoint ?? Point(x: 0, y: 0)
        for d in sh {
            let dx = d.asPoint?.x ?? 0
            let dy = d.asPoint?.y ?? 0
            let pos = Point(x: pPos.x + dx, y: pPos.y + dy)
            // check above
            if dir != "down" && pos.y > 1 {
                let n = playfield[pos.x - 1][pos.y - 2]
                if n != 0, let nPart = partslist[n - 1] {
                    let nType = nPart["type"].asString ?? ""
                    if !propListIdentical(nPart, p) && !nei.contains(where: { propListIdentical($0, nPart) }) && !exclude.contains(nType) {
                        nei.append(nPart)
                    }
                }
            }
            // check below
            if dir != "UP" && pos.y < pf_size[1] {
                let n = playfield[pos.x - 1][pos.y]
                if n != 0, let nPart = partslist[n - 1] {
                    if !propListIdentical(nPart, p) && brickP(nPart) && !nei.contains(where: { propListIdentical($0, nPart) }) {
                        nei.append(nPart)
                    }
                }
            }
        }
        return nei
    }

    func partConnectedGroup(_ p: PropList, group: [PropList]? = nil) -> [PropList] {
        var group = group ?? [p]
        for n in partNeighbors(p) {
            if group.contains(where: { propListIdentical($0, n) }) { continue }
            group.append(n)
            if brickP(n) {
                group = partConnectedGroup(n, group: group)
            }
        }
        return group
    }

    func partSupported(_ p: PropList, group: [PropList]? = nil, ignoregroup: [PropList] = [], recurse: Int = 1) -> LV {
        if supportP(p) { return .string("supported") }
        if !brickP(p) { return .string("illegal") }
        var group = group ?? [p]
        for n in partNeighbors(p, dir: nil, exclude: ["HAZ_FLOAT"]) {
            if ignoregroup.contains(where: { propListIdentical($0, n) }) { continue }
            if group.contains(where: { propListIdentical($0, n) }) { continue }
            group.append(n)
            if brickP(n) {
                let result = partSupported(n, group: group, ignoregroup: ignoregroup, recurse: recurse + 1)
                if let s = result.asString, s == "supported" || s == "illegal" {
                    return result
                }
                // result is a list — not representable as [PropList] directly; use group
            }
        }
        // Return group as a list of propLists
        let gl = LingoList()
        for gp in group { gl.add(.propList(gp)) }
        return .list(gl)
    }

    func findPieceGroup(_ pos: [Int], dir: String) -> [PropList] {
        var pieceGroup = [PropList]()
        var newGroup = [PropList]()
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
            var neighbors = [PropList]()
            for p in newGroup {
                let newneighbors = partNeighbors(p, dir: dir, exclude: ["HAZ_FLOAT"])
                if newneighbors.isEmpty { continue }
                for n in newneighbors {
                    if !neighbors.contains(where: { propListIdentical($0, n) }) {
                        neighbors.append(n)
                    }
                }
                moreNeighbors = true
            }
            for n in neighbors {
                if !brickP(n) || supportP(n) { return [] }
            }
            for p in newGroup {
                if !pieceGroup.contains(where: { propListIdentical($0, p) }) {
                    pieceGroup.append(p)
                }
            }
            newGroup = []
            for n in neighbors {
                if !newGroup.contains(where: { propListIdentical($0, n) }) {
                    newGroup.append(n)
                }
            }
        }
        for p in newGroup {
            if !pieceGroup.contains(where: { propListIdentical($0, p) }) {
                pieceGroup.append(p)
            }
        }
        let oDir = dir == "UP" ? "down" : "UP"
        var newpiecegroup = [PropList]()
        for p in pieceGroup {
            for n in partNeighbors(p, dir: oDir) {
                if pieceGroup.contains(where: { propListIdentical($0, n) }) { continue }
                let result = partSupported(n, ignoregroup: pieceGroup)
                if let s = result.asString {
                    if s == "supported" { continue }
                    if s == "illegal" { return [] }
                }
                if let unsupportedList = result.asList {
                    for i in 1...max(1, unsupportedList.count) {
                        if let u = unsupportedList[i].asPropList {
                            if !brickP(u) { return [] }
                            if !newpiecegroup.contains(where: { propListIdentical($0, u) }) {
                                newpiecegroup.append(u)
                            }
                        }
                    }
                }
            }
        }
        for np in newpiecegroup {
            if !pieceGroup.contains(where: { propListIdentical($0, np) }) {
                pieceGroup.append(np)
            }
        }
        return pieceGroup
    }

    func getPartsByType(_ typelist: LV) -> [PropList] {
        var tlist = [String]()
        if let single = typelist.asString { tlist = [single] }
        else if let tl = typelist.asList {
            for i in 1...max(1, tl.count) { if let s = tl[i].asString { tlist.append(s) } }
        }
        var plist = [PropList]()
        for p in partslist {
            guard let p = p else { continue }
            let pType = p["type"].asString ?? ""
            for t in tlist {
                if pType == t { plist.append(p) }
            }
        }
        return plist
    }

    func getPartsByLabel(_ labelList: LV) -> [PropList] {
        var llist = [String]()
        if let single = labelList.asString { llist = [single] }
        else if let ll = labelList.asList {
            for i in 1...max(1, ll.count) { if let s = ll[i].asString { llist.append(s) } }
        }
        var plist = [PropList]()
        for p in partslist {
            guard let p = p, let plabel = p["label"].asString else { continue }
            for l in llist {
                if plabel == l { plist.append(p) }
            }
        }
        return plist
    }

    func setBackdrop(_ mem: LV) {
        background?["backdrop"] = mem
        refreshBackground()
    }

    func placeDecal(_ d: PropList) {
        guard let s = getASprite() else { return }
        d["sprite"] = .object(s)
        s.member = d["member"].asObject() as? LingoMember
        if let m = d["member"].asObject() as? LingoMember {
            s.rect = m.rect
        }
        s.loc = d["loc"].asPoint ?? Point(x: 0, y: 0)
        s.locZ = decalz
        decalz += 1
        s.blend = 100
        s.visible = true
        s.ink = 36
        if background?["decals"].asList == nil {
            background?["decals"] = .list(LingoList())
        }
        background?["decals"].asList?.add(.propList(d))
    }

    func eraseDecal(_ L: Point) -> PropList? {
        guard background != nil, let decals = background?["decals"].asList else { return nil }
        for i in stride(from: decals.count, through: 1, by: -1) {
            guard let decal = decals[i].asPropList else { continue }
            guard let m = decal["member"].asObject() as? LingoMember,
                  let loc = decal["loc"].asPoint else { continue }
            let r = Rect(
                x: loc.x - (m.regPoint?.x ?? 0),
                y: loc.y - (m.regPoint?.y ?? 0),
                width: m.width,
                height: m.height
            )
            if r.contains(L) {
                if let s = decal["sprite"].asObject() as? LingoSprite {
                    s.loc = Point(x: -100, y: -100)
                    s.member = nil
                    returnASprite(s)
                }
                decals.deleteOne(i)
                return decal
            }
        }
        return nil
    }

    func hideDecals() {
        guard background != nil, let decals = background?["decals"].asList else { return }
        for i in 1...max(1, decals.count) {
            if let decal = decals[i].asPropList {
                if let s = decal["sprite"].asObject() as? LingoSprite {
                    s.loc = Point(x: -100, y: -100)
                    s.member = nil
                    returnASprite(s)
                    decal["sprite"] = .void
                }
            }
        }
    }

    func refreshBackground() {
        glob.EDITOR.playfield_sprite.member = background?["backdrop"].asObject() as? LingoMember
        var z = 10001
        guard let decals = background?["decals"].asList else { return }
        for i in 1...max(1, decals.count) {
            z += 1
            guard let decal = decals[i].asPropList else { continue }
            if decal["sprite"].isVoid {
                if let s = getASprite() {
                    decal["sprite"] = .object(s)
                }
            }
            if let s = decal["sprite"].asObject() as? LingoSprite {
                s.member = decal["member"].asObject() as? LingoMember
                if let m = decal["member"].asObject() as? LingoMember {
                    s.rect = m.rect
                }
                s.loc = decal["loc"].asPoint ?? Point(x: 0, y: 0)
                s.locZ = z
                s.blend = 100
                s.visible = true
                s.ink = 36
            }
        }
        decalz = z + 1
    }

    func getASprite() -> LingoSprite? {
        if spriteBuffer.isEmpty { return nil }
        let s = spriteBuffer.removeFirst()
        s.puppet = 1
        return s
    }

    func returnASprite(_ s: LingoSprite) {
        s.scriptInstanceList = []
        spriteBuffer.append(s)
    }
}

/// Identity comparison for PropList by object reference.
private func propListIdentical(_ a: PropList, _ b: PropList) -> Bool {
    return a === b
}
