// Translated from Lingo: parent_catalog manager.ls

class CatalogManager {
    var cgi: String = "http://www.urth.net/lego_db/levels.cgi"
    var netids: [[Any]] = []
    var cattext: Member? = nil
    var localmode: Bool = false
    var localprefix: String = "lego"
    var localcatalog: [String: Any] = [String: Any]()
    var database: String = "alpha"
    var levelCache: [Any?] = []
    var idToBeCached: [Int] = []
    var levelTitles: [Any?] = []

    init() {
        // localmode = (the environment).internetConnected = #offline
        localmode = !isInternetConnected()
        database = "alpha"
        levelCache = []
        levelTitles = []
        netids = []
        cgi = "http://www.urth.net/lego_db/levels.cgi"
        localprefix = "lego"
        cattext = member("catalog text")
        actorList.append(self)
        idToBeCached = []
    }

    func clickLoad(_ rowid: String) {
        var levelList = [String]()
        let rid = Int(rowid) ?? 0
        for i in stride(from: rid, through: 1, by: -1) {
            let idx = i - 1
            if idx < levelCache.count, let lc = levelCache[idx] as? String {
                levelList.append(lc)
            }
        }
        glob.PLAYER.game_manager.setGame(levelList)
        glob.EDITOR.edit_manager.playfield_manager?.current_level = levelList.first
    }

    func load(_ rowid: Int) {
        if localmode {
            let _ = getPref(localprefix + String(rowid))
            alert("Level loaded")
        } else {
            if !netids.isEmpty { return }
            let nid = postNetText(cgi, ["mode": "load", "rowid": rowid, "database": database])
            netids.append([nid, "load", rowid])
        }
    }

    func catalog() {
        if localmode {
            var t = getPref(localprefix + "cat")
            if t == nil {
                t = ""
                setPref(localprefix + "cat", "")
            }
            do_catalog_2(t ?? "")
        } else {
            if !netids.isEmpty { return }
            let nid = postNetText(cgi, ["mode": "load", "rowid": "all", "database": database])
            netids.append([nid, "catalog"])
            cattext?.text = ""
        }
    }

    func save() {
        if localmode {
            catalog()
            var entry = localcatalog["Entry"] as? [[String: String]] ?? []
            entry.append([
                "name": member("catalog name")?.text ?? "",
                "title": member("catalog title")?.text ?? "",
                "comment": member("catalog comment")?.text ?? ""
            ])
            localcatalog["Entry"] = entry
            var t = ""
            for (i, e) in entry.enumerated() {
                t += "[Entry \(i + 1)]\n"
                t += "Name=\(e["name"] ?? "")\n"
                t += "Title=\(e["title"] ?? "")\n"
                t += "Comment=\(e["comment"] ?? "")\n"
                t += "\n"
            }
            setPref(localprefix + "cat", t)
            setPref(localprefix + String(entry.count), glob.EDITOR.edit_manager.playfield_manager?.current_level ?? "")
            do_catalog_2(t)
        } else {
            if !netids.isEmpty { return }
            let nid = postNetText(cgi, [
                "mode": "save",
                "name": member("catalog name")?.text ?? "",
                "title": member("catalog title")?.text ?? "",
                "comment": member("catalog comment")?.text ?? "",
                "level": glob.EDITOR.edit_manager.playfield_manager?.current_level ?? "",
                "database": database
            ])
            netids.append([nid, "save"])
        }
    }

    func do_catalog(_ nid: Any) {
        let t = netTextResult(nid)
        do_catalog_2(t)
    }

    func do_catalog_2(_ t: String) {
        var rawlevels = [Int: String]()
        var clevel: Int? = nil
        let lines = t.components(separatedBy: "\n")
        let nlt = lines.count
        for (lnIdx, L) in lines.enumerated() {
            let ln = lnIdx + 1
            let words = L.split(separator: " ")
            if words.first == "<<<<" {
                clevel = Int(words.count > 1 ? String(words[1]) : "") ?? nil
                if let c = clevel {
                    rawlevels[c] = ""
                }
            } else if clevel != nil {
                rawlevels[clevel!] = (rawlevels[clevel!] ?? "") + L + "\n"
            }
            if ln % 100 == 0 {
                cattext?.text = "Scanning \(ln) of \(nlt)"
                updateStage()
            }
        }
        var menutext = ""
        var hyperlinkID = [Int]()
        let maxEntry = rawlevels.keys.max() ?? 0
        for entrynum in stride(from: maxEntry, through: 1, by: -1) {
            guard let rl = rawlevels[entrynum], !rl.isEmpty else { continue }
            hyperlinkID.append(entrynum)
            let rlLines = rl.components(separatedBy: "\n")
            let line1 = rlLines.count > 0 ? rlLines[0] : ""
            let line2 = rlLines.count > 1 ? rlLines[1] : ""
            let line3 = rlLines.count > 2 ? rlLines[2] : ""
            menutext += "\(line2) by \(line1) (\(line3) )\n"
            // levelTitles[entrynum] = line2
            while levelTitles.count < entrynum { levelTitles.append(nil) }
            levelTitles[entrynum - 1] = line2
            // Delete first 4 lines, store remainder in levelCache
            let remaining = rlLines.dropFirst(4).joined(separator: "\n")
            while levelCache.count < entrynum { levelCache.append(nil) }
            levelCache[entrynum - 1] = remaining
        }
        // delete trailing char
        if menutext.hasSuffix("\n") { menutext.removeLast() }
        cattext?.text = menutext
        let menuLines = menutext.components(separatedBy: "\n")
        for (i, _) in menuLines.enumerated() {
            let hl = String(hyperlinkID.count > i ? hyperlinkID[i] : 0)
            cattext?.setHyperlink(hl, forLine: i + 1)
        }
    }

    func prepareCache(_ hyperlinkID: [Int]) {
        for id in hyperlinkID {
            if id > levelCache.count {
                idToBeCached.append(id)
                continue
            }
            if !(levelCache[id - 1] is String) {
                idToBeCached.append(id)
            }
        }
    }

    func do_save(_ nid: Any) {
        catalog()
    }

    func do_load(_ nid: Any, rowid: Int) {
        let t = netTextResult(nid)
        while levelCache.count < rowid { levelCache.append(nil) }
        levelCache[rowid - 1] = t
    }

    func stepFrame() {
        if netids.isEmpty {
            sendAllSprites("netReady", 1)
            return
        }
        sendAllSprites("netReady", 0)
        var streamsofar = 0
        var streamtotal = 0
        var toRemove = [Int]()
        for (idx, nid) in netids.enumerated() {
            let ss = getStreamStatus(nid[0])
            streamsofar += ss.bytesSoFar
            streamtotal += ss.bytesTotal
            let nidType = nid[1] as? String ?? ""
            if nidType == "catalog" {
                cattext?.text = "Loading \(streamsofar) of about 200,000"
            }
            if netDone(nid[0]) {
                toRemove.append(idx)
                switch nidType {
                case "load":
                    do_load(nid[0], rowid: nid[2] as? Int ?? 0)
                case "catalog":
                    do_catalog(nid[0])
                case "save":
                    do_save(nid[0])
                default:
                    break
                }
            }
        }
        for idx in toRemove.reversed() { netids.remove(at: idx) }
        if netids.isEmpty && !idToBeCached.isEmpty {
            let id = idToBeCached.removeFirst()
            load(id)
            print("caching \(id)")
        }
    }
}
