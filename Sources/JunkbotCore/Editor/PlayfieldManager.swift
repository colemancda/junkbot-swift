// Translated from Lingo: parent_playfield manager.ls

class PlayfieldManager: LingoObject, @unchecked Sendable {
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

    // Original Lingo body: new
    // ```lingo
    // on new me, conf
    //   if ilk(conf) = #string then
    //     p = glob[#config_manager].parseParams(conf)
    //     conf = p[#playfield]
    //   end if
    //   me.setConfig(conf)
    //   spriteBuffer = []
    //   repeat with i = 200 to 999
    //     spriteBuffer.add(sprite(i))
    //   end repeat
    //   background = [#backdrop: member("bkg1", "backgrounds"), #decals: []]
    //   decalz = 10001
    //   return me
    // end
    // ```
    init(_ conf: LV) {
        super.init()
        var resolvedConf: LV = conf
        if let confStr = conf.asString {
            let p = glob.config_manager.parseParams(confStr)
            resolvedConf = p["playfield"]
        }
        setConfig(resolvedConf)
        for i in 200...999 {
            spriteBuffer.append(sprite(i))
        }
        var bg = PropList()
        bg["backdrop"] = .object(member("bkg1", "backgrounds"))
        bg["decals"] = .list(LingoList())
        background = bg
        decalz = 10001
    }

    // Original Lingo body: leave
    // ```lingo
    // on leave me
    //   current_level = me.toString()
    //   eraseAll(me)
    // end
    // ```
    func leave() {
        current_level = toString()
        eraseAll()
    }

    // Original Lingo body: refresh
    // ```lingo
    // on refresh me
    //   eraseAll(me)
    //   if current_level <> VOID then
    //     setPlayfield(me, current_level)
    //   end if
    // end
    // ```
    func refresh() {
        eraseAll()
        if let cl = current_level {
            setPlayfield(.string(cl))
        }
    }

    // Original Lingo body: setconfig
    // ```lingo
    // on setConfig me, conf
    //   info = [:]
    //   config = conf
    //   pf_size = conf.size
    //   pf_spacing = conf.spacing
    //   pf_scale = conf.scale
    //   pf_grid = pf_spacing * pf_scale
    //   if playfield = VOID then
    //     playfield = []
    //   end if
    //   repeat with i = playfield.count + 1 to pf_size[1]
    //     playfield[i] = []
    //   end repeat
    //   repeat with i = 1 to pf_size[1]
    //     if playfield[i].count < pf_size[2] then
    //       playfield[i][pf_size[2]] = 0
    //     end if
    //   end repeat
    //   if partslist = VOID then
    //     partslist = []
    //   end if
    // end
    // ```
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

    // Original Lingo body: setinfo
    // ```lingo
    // on setInfo me, i
    //   if voidp(i[#title]) or voidp(i[#par]) then
    //     return 
    //   end if
    //   info = i
    //   if voidp(integer(info.par)) then
    //     info.par = 0
    //   end if
    // end
    // ```
    func setInfo(_ i: PropList) {
        guard !i["title"].isVoid, !i["par"].isVoid else { return }
        info = i
        if Int(info["par"].asString ?? "") == nil {
            info["par"] = .int(0)
        }
    }

    // Original Lingo body: getinfo
    // ```lingo
    // on getInfo me
    //   return info
    // end
    // ```
    func getInfo() -> PropList? {
        return info.isEmpty ? nil : info
    }

    // Original Lingo body: tostring
    // ```lingo
    // on toString me
    //   out_partslist = []
    //   out_typelist = [#BLOCK01, #BLOCK02]
    //   out_colorlist = [#GRAY, #blue]
    //   type_map = [#BLOCK01: 1, #BLOCK02: 2]
    //   color_map = [#GRAY: 1, #blue: 2]
    //   repeat with i = 1 to partslist.count
    //     part = partslist[i]
    //     if part <> 0 then
    //       if type_map[part.type] = VOID then
    //         out_typelist.add(part.type)
    //         type_map[part.type] = out_typelist.count
    //         type_num = out_typelist.count
    //       else
    //         type_num = type_map[part.type]
    //       end if
    //       if part.color = VOID then
    //         color_num = 0
    //       else
    //         if color_map[part.color] = VOID then
    //           out_colorlist.add(part.color)
    //           color_map[part.color] = out_colorlist.count
    //           color_num = out_colorlist.count
    //         else
    //           color_num = color_map[part.color]
    //         end if
    //       end if
    //       if voidp(part[#state]) then
    //         state_name = "0"
    //       else
    //         state_name = string(part.state)
    //       end if
    //       if voidp(part[#frame]) then
    //         frame_num = 0
    //       else
    //         frame_num = part.frame
    //       end if
    //       if voidp(part[#label]) then
    //         label_val = "0"
    //       else
    //         label_val = part.label
    //       end if
    //       part_text = part.pos[1] & ";" & part.pos[2] & ";" & type_num & ";" & color_num & ";" & state_name & ";" & frame_num & ";" & label_val
    //       out_partslist.add(part_text)
    //     end if
    //   end repeat
    //   if voidp(background) then
    //     out_bglist = [#backdrop: "bkg1", #decals: []]
    //   else
    //     out_bglist = [#backdrop: background.backdrop.member.name, #decals: []]
    //     repeat with d in background.decals
    //       out_bglist.decals.add(d.loc[1] & ";" & d.loc[2] & ";" & d.member.name)
    //     end repeat
    //   end if
    //   return glob.config_manager.toString([#info: info, #background: out_bglist, #playfield: config, #partslist: [#types: out_typelist, #colors: out_colorlist, #parts: out_partslist]])
    // end
    // ```
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

        var out_bglist = PropList()
        if background == nil {
            out_bglist["backdrop"] = .string("bkg1")
            out_bglist["decals"] = .list(LingoList())
        } else {
            let backdropName = (background?["backdrop"].asObject()?.asMember)?.name ?? "bkg1"
            out_bglist["backdrop"] = .string(backdropName)
            let decalStrings = LingoList()
            if let decalsList = background?["decals"].asList {
                for i in 1...max(1, decalsList.count) {
                    if let d = decalsList[i].asPropList {
                        let loc = d["loc"].asPoint ?? Point(x: 0, y: 0)
                        let mName = (d["member"].asObject()?.asMember)?.name ?? ""
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
        var partslistPL = PropList()
        partslistPL["types"] = .list(typesList)
        partslistPL["colors"] = .list(colorsList)
        partslistPL["parts"] = .list(partsList)

        var wrapper = PropList()
        wrapper["info"] = .propList(info)
        wrapper["background"] = .propList(out_bglist)
        wrapper["playfield"] = .propList(config)
        wrapper["partslist"] = .propList(partslistPL)
        return glob.config_manager.toString(wrapper)
    }

    // Original Lingo body: setplayfield
    // ```lingo
    // on setPlayfield me, pfinfo, opt
    //   playfield = VOID
    //   partslist = VOID
    //   setConfig(me, config)
    //   if ilk(pfinfo) = #string then
    //     pfinfo = glob.config_manager.parseParams(pfinfo)
    //   end if
    //   if not voidp(pfinfo[#info]) then
    //     info = pfinfo.info
    //   end if
    //   if voidp(pfinfo[#background]) then
    //     pfinfo[#background] = [#backdrop: "bkg1", #decals: []]
    //   end if
    //   background = [#decals: []]
    //   background[#backdrop] = member(pfinfo.background.backdrop, "backgrounds")
    //   if ilk(pfinfo.background.decals) <> #list then
    //     pfinfo.background.decals = [pfinfo.background.decals]
    //   end if
    //   repeat with d in pfinfo.background.decals
    //     tid = the itemDelimiter
    //     the itemDelimiter = ";"
    //     decal_loc_x = integer(item 1 of d)
    //     if not voidp(decal_loc_x) then
    //       decal_loc_y = integer(item 2 of d)
    //       decal_member_name = string(item 3 of d)
    //       background.decals.add([#member: member(decal_member_name, "backgrounds"), #loc: point(decal_loc_x, decal_loc_y)])
    //     end if
    //     the itemDelimiter = tid
    //   end repeat
    //   me.refreshBackground()
    //   pf = pfinfo.partslist
    //   if (pf[#parts] = VOID) or (pf[#parts] = EMPTY) then
    //     pf[#parts] = []
    //   else
    //     if ilk(pf.parts) = #string then
    //       pf.parts = [pf.parts]
    //     end if
    //   end if
    //   repeat with p in pf.parts
    //     tid = the itemDelimiter
    //     the itemDelimiter = ";"
    //     part_pos_x = integer(item 1 of p)
    //     part_pos_y = integer(item 2 of p)
    //     part_typenum = integer(item 3 of p)
    //     part_colornum = integer(item 4 of p)
    //     part_statename = string(item 5 of p)
    //     part_framenum = integer(item 6 of p)
    //     part_labelval = string(item 7 of p)
    //     the itemDelimiter = tid
    //     part_type = pf.types[part_typenum]
    //     if part_colornum = 0 then
    //       part_color = VOID
    //     else
    //       part_color = pf.colors[part_colornum]
    //     end if
    //     part = [#pos: point(part_pos_x, part_pos_y), #type: symbol(part_type), #color: symbol(part_color)]
    //     if part_labelval <> "0" then
    //       part[#label] = part_labelval
    //     end if
    //     if not voidp(part_statename) and (part_statename <> "0") and (part_statename <> EMPTY) then
    //       part[#state] = symbol(part_statename)
    //     end if
    //     if not voidp(part_framenum) and (part_framenum <> 0) then
    //       part[#frame] = part_framenum
    //     end if
    //     case part.type of
    //       #HAZ_SLICKFIRE, #HAZ_SLICKFAN:
    //         if (part[#state] <> #off) and (part[#state] <> #on) then
    //           part.state = #on
    //         end if
    //     end case
    //     me.placePiece(part)
    //   end repeat
    //   current_level = me.toString()
    // end
    // ```
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
            var defaultBg = PropList()
            defaultBg["backdrop"] = .string("bkg1")
            defaultBg["decals"] = .list(LingoList())
            pfinfoDict["background"] = .propList(defaultBg)
        }
        var bg = PropList()
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
                        var decalPL = PropList()
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
                var part = PropList()
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

    // Original Lingo body: makegrid
    // ```lingo
    // on makeGrid me
    //   bg_image = image(pf_size[1] * pf_grid[1], pf_size[2] * pf_grid[2], 16)
    //   bg_image.fill(bg_image.rect, rgb(190, 225, 190))
    //   repeat with i = 1 to pf_size[1] - 1
    //     repeat with j = 1 to pf_size[2] - 1
    //       bg_image.setPixel(i * pf_grid[1], j * pf_grid[2], rgb(128, 128, 128))
    //     end repeat
    //   end repeat
    //   epg = member("editor-playfield grid")
    //   epg.image = bg_image
    //   epg.regPoint = point(0, 0)
    // end
    // ```
    func makeGrid() {
        bg_image = .void // image(pf_size[0] * pf_grid[0], pf_size[1] * pf_grid[1], 16)
        // fill bg_image with rgb(190, 225, 190)
        // draw grid dots at rgb(128, 128, 128)
        // member("editor-playfield grid").image = bg_image
        // member("editor-playfield grid").regPoint = Point(x: 0, y: 0)
    }

    // Original Lingo body: getpos
    // ```lingo
    // on getPos me, L
    //   if glob.EDITOR[#playfield_sprite] = VOID then
    //     return VOID
    //   end if
    //   p = (L - glob.EDITOR.playfield_sprite.loc) / pf_grid
    //   l2 = ((p + [0, 1]) * pf_grid) + glob.EDITOR.playfield_sprite.loc
    //   p = p + [1, 1]
    //   if (p[1] < 1) or (p[2] < 1) or (p[1] > pf_size[1]) or (p[2] > pf_size[2]) then
    //     return VOID
    //   end if
    //   return [p, l2]
    // end
    // ```
    func getPos(_ L: Point) -> [LV]? {
        guard !glob.EDITOR["playfield_sprite"].isVoid else { return nil }
        let spriteLoc = glob.EDITOR.playfield_sprite.loc.asPoint ?? Point(x: 0, y: 0)
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

    // Original Lingo body: getloc
    // ```lingo
    // on getLoc me, arg
    //   o = point(0, 0)
    //   if ilk(arg) = #propList then
    //     p = arg.pos
    //     if not voidp(arg[#pixelOffset]) then
    //       o = arg.pixelOffset
    //     end if
    //   else
    //     p = arg
    //   end if
    //   return ((p - [1, 0]) * pf_grid) + glob.EDITOR.playfield_sprite.loc + o
    // end
    // ```
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
        let spriteLoc = glob.EDITOR.playfield_sprite.loc.asPoint ?? Point(x: 0, y: 0)
        return Point(
            x: ((p.x - 1) * pf_grid[0]) + spriteLoc.x + o.x,
            y: (p.y * pf_grid[1]) + spriteLoc.y + o.y
        )
    }

    // Original Lingo body: getpart
    // ```lingo
    // on getPart me, pos
    //   p = playfield[pos[1]][pos[2]]
    //   if p = 0 then
    //     return VOID
    //   end if
    //   return partslist[p]
    // end
    // ```
    func getPart(_ pos: LV) -> PropList? {
        guard let pt = pos.asPoint else { return nil }
        let x = pt.x - 1, y = pt.y - 1
        guard x >= 0, y >= 0, x < playfield.count, y < (playfield.first?.count ?? 0) else { return nil }
        let p = playfield[x][y]
        if p == 0 { return nil }
        return partslist[p - 1]
    }

    // Original Lingo body: checkfit
    // ```lingo
    // on checkFit me, pos, typ
    //   sh = glob.legoparts_manager.getPieceShape(typ)
    //   fit = 1
    //   repeat with i = 1 to sh.count
    //     t = pos + sh[i]
    //     if (t[1] < 1) or (t[2] < 1) or (t[1] > pf_size[1]) or (t[2] > pf_size[2]) then
    //       fit = 0
    //       exit repeat
    //       next repeat
    //     end if
    //     if playfield[t[1]][t[2]] <> 0 then
    //       fit = 0
    //       exit repeat
    //     end if
    //   end repeat
    //   return fit
    // end
    // ```
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

    // Original Lingo body: checkfitorgoal
    // ```lingo
    // on checkFitOrGoal me, pos, typ
    //   sh = glob.legoparts_manager.getPieceShape(typ)
    //   fit = 1
    //   goal = VOID
    //   repeat with i = 1 to sh.count
    //     t = pos + sh[i]
    //     if (t[1] < 1) or (t[2] < 1) or (t[1] > pf_size[1]) or (t[2] > pf_size[2]) then
    //       fit = 0
    //       goal = VOID
    //       exit repeat
    //       next repeat
    //     end if
    //     pnum = playfield[t[1]][t[2]]
    //     if pnum <> 0 then
    //       p = partslist[pnum]
    //       if me.goalP(p) then
    //         goal = p
    //         next repeat
    //       end if
    //       fit = 0
    //       goal = VOID
    //       exit repeat
    //     end if
    //   end repeat
    //   if goal = VOID then
    //     return fit
    //   else
    //     return goal
    //   end if
    // end
    // ```
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

    // Original Lingo body: checkfitornonbrick
    // ```lingo
    // on checkFitOrNonbrick me, pos, typ
    //   sh = glob.legoparts_manager.getPieceShape(typ)
    //   fit = 1
    //   nonbrick = VOID
    //   repeat with i = 1 to sh.count
    //     t = pos + sh[i]
    //     if (t[1] < 1) or (t[2] < 1) or (t[1] > pf_size[1]) or (t[2] > pf_size[2]) then
    //       fit = 0
    //       nonbrick = VOID
    //       exit repeat
    //       next repeat
    //     end if
    //     pnum = playfield[t[1]][t[2]]
    //     if pnum <> 0 then
    //       p = partslist[pnum]
    //       if not me.brickP(p) then
    //         nonbrick = p
    //         next repeat
    //       end if
    //       fit = 0
    //       nonbrick = VOID
    //       exit repeat
    //     end if
    //   end repeat
    //   if nonbrick = VOID then
    //     return fit
    //   else
    //     return nonbrick
    //   end if
    // end
    // ```
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

    // Original Lingo body: checkfitorminifig
    // ```lingo
    // on checkFitOrMinifig me, pos, typ
    //   sh = glob.legoparts_manager.getPieceShape(typ)
    //   fit = 1
    //   goal = VOID
    //   repeat with i = 1 to sh.count
    //     t = pos + sh[i]
    //     if (t[1] < 1) or (t[2] < 1) or (t[1] > pf_size[1]) or (t[2] > pf_size[2]) then
    //       fit = 0
    //       goal = VOID
    //       exit repeat
    //       next repeat
    //     end if
    //     pnum = playfield[t[1]][t[2]]
    //     if pnum <> 0 then
    //       p = partslist[pnum]
    //       if me.minifigP(p) then
    //         goal = p
    //         next repeat
    //       end if
    //       fit = 0
    //       goal = VOID
    //       exit repeat
    //     end if
    //   end repeat
    //   if goal = VOID then
    //     return fit
    //   else
    //     return goal
    //   end if
    // end
    // ```
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

    // Original Lingo body: checkfitminifighit
    // ```lingo
    // on checkFitMiniFigHit me, pos, typ
    //   sh = glob.legoparts_manager.getPieceShape(typ)
    //   fit = 1
    //   goal = VOID
    //   repeat with i = 1 to sh.count
    //     t = pos + sh[i]
    //     if (t[1] < 1) or (t[2] < 1) or (t[1] > pf_size[1]) or (t[2] > pf_size[2]) then
    //       fit = 0
    //       goal = VOID
    //       exit repeat
    //       next repeat
    //     end if
    //     pnum = playfield[t[1]][t[2]]
    //     if pnum <> 0 then
    //       p = partslist[pnum]
    //       if me.minifigP(p) then
    //         goal = p
    //       else
    //         goal = VOID
    //       end if
    //       fit = 0
    //       exit repeat
    //     end if
    //   end repeat
    //   if not voidp(goal) then
    //     glob.PLAYER[#minifigHit] = goal
    //   end if
    //   return fit
    // end
    // ```
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

    // Original Lingo body: checkplaceable
    // ```lingo
    // on checkPlaceable me, pos, typ
    //   sh = glob.legoparts_manager.getPieceShape(typ)
    //   fit = 1
    //   edgetop = #free
    //   edgebottom = #free
    //   repeat with i = 1 to sh.count
    //     t = pos + sh[i]
    //     if (t[1] < 1) or (t[2] < 1) or (t[1] > pf_size[1]) or (t[2] > pf_size[2]) then
    //       fit = 0
    //       exit repeat
    //     else
    //       if playfield[t[1]][t[2]] <> 0 then
    //         fit = 0
    //         exit repeat
    //       end if
    //     end if
    //     if t[2] > 1 then
    //       above = playfield[t[1]][t[2] - 1]
    //       if above <> 0 then
    //         if me.brickP(partslist[above]) then
    //           edgetop = #brick
    //         else
    //           if me.slickBrickP(partslist[above]) then
    //             fit = 0
    //             exit repeat
    //           end if
    //         end if
    //       end if
    //     end if
    //     if t[2] = pf_size[2] then
    //       edgebottom = #bottom
    //       next repeat
    //     end if
    //     below = playfield[t[1]][t[2] + 1]
    //     if below <> 0 then
    //       if me.brickP(partslist[below]) then
    //         edgebottom = #brick
    //         next repeat
    //       end if
    //       if me.slickBrickP(partslist[below]) then
    //         fit = 0
    //         exit repeat
    //       end if
    //     end if
    //   end repeat
    //   if not fit then
    //     return #nofit
    //   end if
    //   if (edgetop = #free) and ((edgebottom = #free) or (edgebottom = #bottom)) then
    //     return #fit
    //   end if
    //   if (edgebottom <> #free) and (edgetop = #free) then
    //     return #below
    //   end if
    //   if ((edgebottom = #free) or (edgebottom = #bottom)) and (edgetop <> #free) then
    //     return #above
    //   end if
    //   return #nofit
    // end
    // ```
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

    // Original Lingo body: checkfloor
    // ```lingo
    // on checkFloor me, pos, w
    //   n = 0
    //   repeat with i = 0 to w - 1
    //     x = pos[1] + i
    //     if (x > 0) and (x <= pf_size[1]) then
    //       if pos[2] < pf_size[2] then
    //         pnum = playfield[x][pos[2] + 1]
    //         if pnum <> 0 then
    //           n = n + (me.brickP(partslist[pnum]) or me.slickBrickP(partslist[pnum]))
    //         end if
    //         next repeat
    //       end if
    //       n = n + 1
    //     end if
    //   end repeat
    //   return n
    // end
    // ```
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

    // Original Lingo body: placepiece
    // ```lingo
    // on placePiece me, pos, typ, mem, col, spr
    //   if ilk(pos) = #propList then
    //     part = pos
    //   else
    //     part = [#pos: pos, #type: typ, #color: col, #member: mem, #sprite: spr]
    //   end if
    //   partmembers = glob.legoparts_manager.getPieceMemberName(part)
    //   if voidp(part[#sprite]) then
    //     part[#sprite] = []
    //     repeat with si = 1 to partmembers.count
    //       s = me.getASprite()
    //       part.sprite.add(s)
    //     end repeat
    //   end if
    //   partslist.add(part)
    //   partnum = partslist.count
    //   sh = glob.legoparts_manager.getPieceShape(part.type)
    //   repeat with i = 1 to sh.count
    //     t = part.pos + sh[i]
    //     playfield[t[1]][t[2]] = partnum
    //   end repeat
    //   repeat with si = 1 to part.sprite.count
    //     s = part.sprite[si]
    //     s.puppet = 1
    //     s.member = member(partmembers[si])
    //     s.width = s.member.width * pf_scale
    //     s.height = s.member.height * pf_scale
    //     s.loc = me.getLoc(part)
    //     s.visible = 1
    //     if me.brickP(part) then
    //       s.ink = 8
    //     else
    //       s.ink = 36
    //     end if
    //     s.locZ = me.posToLocZ(part.pos - point(0, si - 1))
    //     s.blend = 100
    //     s.scriptInstanceList.add(new(script("part click behavior"), part))
    //   end repeat
    //   if not voidp(part[#behavior]) then
    //     part.behavior.notify([#Start: 1])
    //   end if
    // end
    // ```
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
                guard let s = spriteList[si].asObject()?.asSprite else { continue }
                s.puppet = true
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
                s.scriptInstanceList.append(BehaviorPartClick(p: .propList(part)))
            }
        }
        if let behavior = part["behavior"].asObject() {
            behavior.notify(PropList([("Start", .int(1))]))
        }
    }

    // Original Lingo body: postolocz
    // ```lingo
    // on posToLocZ me, pos
    //   return 100000 - (1000 * pos[2]) + pos[1]
    // end
    // ```
    func posToLocZ(_ pos: Point) -> Int {
        return 100000 - (1000 * pos.y) + pos.x
    }

    // Original Lingo body: placepiecegroup
    // ```lingo
    // on placePieceGroup me, partgroup
    //   repeat with part in partgroup
    //     me.placePiece(part)
    //   end repeat
    // end
    // ```
    func placePieceGroup(_ partgroup: [PropList]) {
        for part in partgroup {
            placePiece(part)
        }
    }

    // Original Lingo body: erasepiece
    // ```lingo
    // on erasePiece me, pos, keepSprite
    //   partnum = playfield[pos[1]][pos[2]]
    //   if partnum = 0 then
    //     return VOID
    //   end if
    //   part = partslist[partnum]
    //   partslist[partnum] = 0
    //   if ilk(part) = #propList then
    //     basepos = part.pos
    //     sh = glob.legoparts_manager.getPieceShape(part.type)
    //     repeat with i = 1 to sh.count
    //       t = basepos + sh[i]
    //       playfield[t[1]][t[2]] = 0
    //     end repeat
    //   end if
    //   if keepSprite <> 1 then
    //     if not voidp(part[#sprite]) then
    //       repeat with s in part.sprite
    //         s.loc = [-100, -100]
    //         s.visible = 0
    //         s.scriptInstanceList = []
    //         me.returnASprite(s)
    //       end repeat
    //       part[#sprite] = VOID
    //     end if
    //     if not voidp(part[#auxSprites]) then
    //       repeat with s in part.auxSprites
    //         s.loc = [-100, -100]
    //         s.visible = 0
    //         s.scriptInstanceList = []
    //         me.returnASprite(s)
    //       end repeat
    //       part[#auxSprites] = [:]
    //     end if
    //   end if
    //   if not voidp(part[#behavior]) then
    //     part.behavior.notify([#stop: 1])
    //   end if
    //   return part
    // end
    // ```
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
                    if let s = spriteList[i].asObject()?.asSprite {
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
                    if let s = auxSpriteList[i].asObject()?.asSprite {
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
            behavior.notify(PropList([("stop", .int(1))]))
        }
        return part
    }

    // Original Lingo body: erasepiecegroup
    // ```lingo
    // on erasePieceGroup me, partgroup, keepSprites
    //   erasedPieces = []
    //   repeat with part in partgroup
    //     erasedPieces.add(me.erasePiece(part.pos, keepSprites))
    //   end repeat
    //   return erasedPieces
    // end
    // ```
    func erasePieceGroup(_ partgroup: [PropList], keepSprites: Bool = false) -> [PropList?] {
        var erasedPieces = [PropList?]()
        for part in partgroup {
            erasedPieces.append(erasePiece(part["pos"], keepSprite: keepSprites))
        }
        return erasedPieces
    }

    // Original Lingo body: releasepiecesprite
    // ```lingo
    // on releasePieceSprite me, p
    //   s = p.sprite
    //   if s <> VOID then
    //     s.loc = [-100, -100]
    //     s.visible = 0
    //     me.returnASprite(s)
    //   end if
    //   p[#sprite] = VOID
    // end
    // ```
    func releasePieceSprite(_ p: PropList) {
        if let s = p["sprite"].asObject()?.asSprite {
            s.loc = Point(x: -100, y: -100)
            s.visible = false
            returnASprite(s)
        }
        p["sprite"] = .void
    }

    // Original Lingo body: releasepiecegroupsprites
    // ```lingo
    // on releasePieceGroupSprites me, partgroup
    //   repeat with p in partgroup
    //     me.releasePieceSprite(p)
    //   end repeat
    // end
    // ```
    func releasePieceGroupSprites(_ partgroup: [PropList]) {
        for p in partgroup {
            releasePieceSprite(p)
        }
    }

    // Original Lingo body: eraseall
    // ```lingo
    // on eraseAll me
    //   repeat with part in partslist
    //     if part <> 0 then
    //       me.erasePiece(part.pos)
    //     end if
    //   end repeat
    //   me.hideDecals()
    // end
    // ```
    func eraseAll() {
        for part in partslist {
            if let part = part {
                _ = erasePiece(part["pos"])
            }
        }
        hideDecals()
    }

    // Original Lingo body: brickp
    // ```lingo
    // on brickP me, p
    //   if p = 0 then
    //     return 0
    //   end if
    //   return string(p.type) contains "BRICK"
    // end
    // ```
    func brickP(_ p: PropList) -> Bool {
        return (p["type"].asString ?? "").contains("BRICK")
    }

    // Original Lingo body: slickbrickp
    // ```lingo
    // on slickBrickP me, p
    //   if p = 0 then
    //     return 0
    //   end if
    //   return string(p.type) contains "_SLICK"
    // end
    // ```
    func slickBrickP(_ p: PropList) -> Bool {
        return (p["type"].asString ?? "").contains("_SLICK")
    }

    // Original Lingo body: supportp
    // ```lingo
    // on supportP me, p
    //   if p = 0 then
    //     return 0
    //   end if
    //   return me.brickP(p) and (string(p.color) contains "GRAY")
    // end
    // ```
    func supportP(_ p: PropList) -> Bool {
        return brickP(p) && (p["color"].asString ?? "").contains("GRAY")
    }

    // Original Lingo body: goalp
    // ```lingo
    // on goalP me, p
    //   if p = 0 then
    //     return 0
    //   end if
    //   return string(p.type) contains "FLAG"
    // end
    // ```
    func goalP(_ p: PropList) -> Bool {
        return (p["type"].asString ?? "").contains("FLAG")
    }

    // Original Lingo body: minifigp
    // ```lingo
    // on minifigP me, p
    //   if p = 0 then
    //     return 0
    //   end if
    //   return string(p.type) contains "MINIFIG"
    // end
    // ```
    func minifigP(_ p: PropList) -> Bool {
        return (p["type"].asString ?? "").contains("MINIFIG")
    }

    // Original Lingo body: partneighbors
    // ```lingo
    // on partNeighbors me, p, dir, exclude
    //   if p = 0 then
    //     return []
    //   end if
    //   if voidp(exclude) then
    //     exclude = []
    //   end if
    //   nei = []
    //   sh = glob.legoparts_manager.getPieceShape(p.type)
    //   repeat with d in sh
    //     pos = p.pos + d
    //     if not (dir = #down) and (pos[2] > 1) then
    //       n = playfield[pos[1]][pos[2] - 1]
    //       if n <> 0 then
    //         n = partslist[n]
    //         if (n <> p) and not nei.getOne(n) and not exclude.getOne(n.type) then
    //           nei.add(n)
    //         end if
    //       end if
    //     end if
    //     if not (dir = #UP) and (pos[2] < pf_size[2]) then
    //       n = playfield[pos[1]][pos[2] + 1]
    //       if n <> 0 then
    //         n = partslist[n]
    //         if (n <> p) and me.brickP(n) and not nei.getOne(n) then
    //           nei.add(n)
    //         end if
    //       end if
    //     end if
    //   end repeat
    //   return nei
    // end
    // ```
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

    // Original Lingo body: partconnectedgroup
    // ```lingo
    // on partConnectedGroup me, p, group
    //   if p = 0 then
    //     return []
    //   end if
    //   if group = VOID then
    //     group = [p]
    //   end if
    //   repeat with n in me.partNeighbors(p)
    //     if group.getOne(n) then
    //       next repeat
    //     end if
    //     group.add(n)
    //     if me.brickP(n) then
    //       group = me.partConnectedGroup(n, group)
    //     end if
    //   end repeat
    //   return group
    // end
    // ```
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

    // Original Lingo body: partsupported
    // ```lingo
    // on partSupported me, p, group, ignoregroup, recurse
    //   if voidp(ignoregroup) then
    //     ignoregroup = []
    //   end if
    //   if p = 0 then
    //     return []
    //   end if
    //   if voidp(recurse) then
    //     recurse = 1
    //   end if
    //   ms = the milliSeconds
    //   if me.supportP(p) then
    //     return #supported
    //   else
    //     if not me.brickP(p) then
    //       return #illegal
    //     end if
    //   end if
    //   if group = VOID then
    //     group = [p]
    //   end if
    //   repeat with n in me.partNeighbors(p, VOID, [#HAZ_FLOAT])
    //     ms2 = the milliSeconds
    //     if ignoregroup.getOne(n) then
    //       next repeat
    //     end if
    //     if group.getOne(n) then
    //       next repeat
    //     end if
    //     group.add(n)
    //     if me.brickP(n) then
    //       group = me.partSupported(n, group, ignoregroup, recurse + 1)
    //     end if
    //     if (group = #supported) or (group = #illegal) then
    //       exit repeat
    //     end if
    //   end repeat
    //   if ilk(group) = #list then
    //     tmp = group.count
    //   else
    //     tmp = group
    //   end if
    //   repeat with i = 1 to recurse - 1
    //     tmp = "." & tmp
    //   end repeat
    //   return group
    // end
    // ```
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

    // Original Lingo body: findpiecegroup
    // ```lingo
    // on findPieceGroup me, pos, dir
    //   pieceGroup = []
    //   newGroup = []
    //   firstpartnum = playfield[pos[1]][pos[2]]
    //   if firstpartnum = 0 then
    //     return []
    //   end if
    //   firstpart = partslist[firstpartnum]
    //   if not me.brickP(firstpart) or me.supportP(firstpart) then
    //     return []
    //   end if
    //   newGroup.add(firstpart)
    //   moreNeighbors = 1
    //   repeat while moreNeighbors
    //     moreNeighbors = 0
    //     neighbors = []
    //     repeat with p in newGroup
    //       newneighbors = me.partNeighbors(p, dir, [#HAZ_FLOAT])
    //       if newneighbors = [] then
    //         next repeat
    //         next repeat
    //       end if
    //       repeat with n in newneighbors
    //         if not neighbors.getOne(n) then
    //           neighbors.add(n)
    //         end if
    //       end repeat
    //       moreNeighbors = 1
    //     end repeat
    //     repeat with n in neighbors
    //       if not me.brickP(n) or me.supportP(n) then
    //         return []
    //       end if
    //     end repeat
    //     repeat with p in newGroup
    //       if not pieceGroup.getOne(p) then
    //         pieceGroup.add(p)
    //       end if
    //     end repeat
    //     newGroup = []
    //     repeat with n in neighbors
    //       if not newGroup.getOne(n) then
    //         newGroup.add(n)
    //       end if
    //     end repeat
    //   end repeat
    //   repeat with p in newGroup
    //     if not pieceGroup.getOne(p) then
    //       pieceGroup.add(p)
    //     end if
    //   end repeat
    //   unsupportedGroup = []
    //   case dir of
    //     #UP:
    //       oDir = #down
    //     #down:
    //       oDir = #UP
    //   end case
    //   newpiecegroup = []
    //   repeat with p in pieceGroup
    //     newneighbors = me.partNeighbors(p, oDir)
    //     repeat with n in newneighbors
    //       if pieceGroup.getOne(n) then
    //         next repeat
    //       end if
    //       unsupportedGroup = me.partSupported(n, VOID, pieceGroup)
    //       if unsupportedGroup = #supported then
    //         next repeat
    //       end if
    //       if unsupportedGroup = #illegal then
    //         return []
    //       end if
    //       repeat with U in unsupportedGroup
    //         if not me.brickP(U) then
    //           return []
    //         end if
    //         if not newpiecegroup.getOne(U) then
    //           newpiecegroup.add(U)
    //         end if
    //       end repeat
    //     end repeat
    //   end repeat
    //   repeat with np in newpiecegroup
    //     if not pieceGroup.getOne(np) then
    //       pieceGroup.add(np)
    //     end if
    //   end repeat
    //   return pieceGroup
    // end
    // ```
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

    // Original Lingo body: getpartsbytype
    // ```lingo
    // on getPartsByType me, typelist
    //   plist = []
    //   if ilk(typelist) <> #list then
    //     typelist = [typelist]
    //   end if
    //   repeat with p in partslist
    //     if p = 0 then
    //       next repeat
    //     end if
    //     repeat with t in typelist
    //       if p.type = t then
    //         plist.add(p)
    //       end if
    //     end repeat
    //   end repeat
    //   return plist
    // end
    // ```
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

    // Original Lingo body: getpartsbylabel
    // ```lingo
    // on getPartsByLabel me, labelList
    //   plist = []
    //   if ilk(labelList) <> #list then
    //     labelList = [labelList]
    //   end if
    //   repeat with p in partslist
    //     if p = 0 then
    //       next repeat
    //     end if
    //     if voidp(p[#label]) then
    //       next repeat
    //     end if
    //     repeat with L in labelList
    //       if p[#label] = L then
    //         plist.add(p)
    //       end if
    //     end repeat
    //   end repeat
    //   return plist
    // end
    // ```
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

    // Original Lingo body: setbackdrop
    // ```lingo
    // on setBackdrop me, mem
    //   background.backdrop = mem
    //   me.refreshBackground()
    // end
    // ```
    func setBackdrop(_ mem: LV) {
        background?["backdrop"] = mem
        refreshBackground()
    }

    // Original Lingo body: placedecal
    // ```lingo
    // on placeDecal me, d
    //   decal = d.duplicate()
    //   decal[#sprite] = me.getASprite()
    //   decal.sprite.member = decal.member
    //   decal.sprite.rect = decal.member.rect
    //   decal.sprite.loc = decal.loc
    //   decal.sprite.locZ = decalz
    //   decalz = decalz + 1
    //   decal.sprite.blend = 100
    //   decal.sprite.visible = 1
    //   decal.sprite.ink = 36
    //   background.decals.add(decal)
    // end
    // ```
    func placeDecal(_ d: PropList) {
        guard let s = getASprite() else { return }
        d["sprite"] = .object(s)
        s.member = d["member"].asObject()?.asMember
        if let m = d["member"].asObject()?.asMember {
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

    // Original Lingo body: erasedecal
    // ```lingo
    // on eraseDecal me, L
    //   if voidp(background) then
    //     return 
    //   end if
    //   if voidp(background.decals) then
    //     return 
    //   end if
    //   repeat with d = background.decals.count down to 1
    //     decal = background.decals[d]
    //     r = rect(decal.loc - decal.member.regPoint, decal.loc - decal.member.regPoint + point(decal.member.width, decal.member.height))
    //     if inside(L, r) then
    //       if not voidp(decal.sprite) then
    //         decal.sprite.loc = point(-100, -100)
    //         decal.sprite.member = member(0)
    //         me.returnASprite(decal.sprite)
    //         decal.sprite = VOID
    //       end if
    //       background.decals.deleteOne(decal)
    //       return decal.duplicate()
    //     end if
    //   end repeat
    // end
    // ```
    func eraseDecal(_ L: Point) -> PropList? {
        guard background != nil, let decals = background?["decals"].asList else { return nil }
        for i in stride(from: decals.count, through: 1, by: -1) {
            guard let decal = decals[i].asPropList else { continue }
            guard let m = decal["member"].asObject()?.asMember,
                  let loc = decal["loc"].asPoint else { continue }
            let r = Rect(
                x: loc.x - m.regPoint.x,
                y: loc.y - m.regPoint.y,
                width: m.width,
                height: m.height
            )
            if r.contains(L) {
                if let s = decal["sprite"].asObject()?.asSprite {
                    s.loc = Point(x: -100, y: -100)
                    s.member = nil
                    returnASprite(s)
                }
                decals.deleteAt(i)
                return decal
            }
        }
        return nil
    }

    // Original Lingo body: hidedecals
    // ```lingo
    // on hideDecals me
    //   if voidp(background) then
    //     return 
    //   end if
    //   if voidp(background.decals) then
    //     return 
    //   end if
    //   repeat with decal in background.decals
    //     if not voidp(decal[#sprite]) then
    //       decal.sprite.loc = point(-100, -100)
    //       decal.sprite.member = member(0)
    //       me.returnASprite(decal.sprite)
    //       decal.sprite = VOID
    //     end if
    //   end repeat
    // end
    // ```
    func hideDecals() {
        guard background != nil, let decals = background?["decals"].asList else { return }
        for i in 1...max(1, decals.count) {
            if let decal = decals[i].asPropList {
                if let s = decal["sprite"].asObject()?.asSprite {
                    s.loc = Point(x: -100, y: -100)
                    s.member = nil
                    returnASprite(s)
                    decal["sprite"] = .void
                }
            }
        }
    }

    // Original Lingo body: refreshbackground
    // ```lingo
    // on refreshBackground me
    //   glob.EDITOR.playfield_sprite.member = background.backdrop
    //   z = 10001
    //   repeat with decal in background.decals
    //     z = z + 1
    //     if voidp(decal[#sprite]) then
    //       decal[#sprite] = me.getASprite()
    //     end if
    //     decal.sprite.member = decal.member
    //     decal.sprite.rect = decal.member.rect
    //     decal.sprite.loc = decal.loc
    //     decal.sprite.locZ = z
    //     decal.sprite.blend = 100
    //     decal.sprite.visible = 1
    //     decal.sprite.ink = 36
    //   end repeat
    //   decalz = z + 1
    // end
    // ```
    func refreshBackground() {
        let backdrop = background?["backdrop"] ?? .void
        if let backdropMember = backdrop.asObject()?.asMember {
            glob.EDITOR.playfield_sprite.member = .object(backdropMember)
        } else if let backdropName = backdrop.asString, let backdropMember = member(backdropName) {
            glob.EDITOR.playfield_sprite.member = .object(backdropMember)
        } else {
            glob.EDITOR.playfield_sprite.member = .void
        }
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
            if let s = decal["sprite"].asObject()?.asSprite {
                s.member = decal["member"].asObject()?.asMember
                if let m = decal["member"].asObject()?.asMember {
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

    // Original Lingo body: getasprite
    // ```lingo
    // on getASprite me
    //   if spriteBuffer.count = 0 then
    //     return VOID
    //   end if
    //   s = spriteBuffer[1]
    //   s.puppet = 1
    //   deleteAt(spriteBuffer, 1)
    //   return s
    // end
    // ```
    func getASprite() -> LingoSprite? {
        if spriteBuffer.isEmpty { return nil }
        let s = spriteBuffer.removeFirst()
        s.puppet = true
        return s
    }

    // Original Lingo body: returnasprite
    // ```lingo
    // on returnASprite me, s
    //   s.scriptInstanceList = []
    //   spriteBuffer.add(s)
    // end
    // ```
    func returnASprite(_ s: LingoSprite) {
        s.scriptInstanceList = []
        spriteBuffer.append(s)
    }
}

/// Identity comparison for PropList by object reference.
private func propListIdentical(_ a: PropList, _ b: PropList) -> Bool {
    return a === b
}
