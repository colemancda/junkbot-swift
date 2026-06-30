// Translated from Lingo: parent_catalog manager.ls

class CatalogManager: LingoObject, @unchecked Sendable {
    var cgi: String = "http://www.urth.net/lego_db/levels.cgi"
    var netids: [[LV]] = []
    var cattext: LingoMember? = nil
    var localmode: Bool = false
    var localprefix: String = "lego"
    var localcatalog: PropList = PropList()
    var database: String = "alpha"
    var levelCache: [LV] = []
    var idToBeCached: [Int] = []
    var levelTitles: [LV] = []

    override init() {
        // localmode = (the environment).internetConnected = #offline
        localmode = !isInternetConnected()
        database = "alpha"
        levelCache = []
        levelTitles = []
        netids = []
        cgi = "http://www.urth.net/lego_db/levels.cgi"
        localprefix = "lego"
        cattext = member("catalog text")
        actorList.append(self as LingoObject)
        idToBeCached = []
    }

    func clickLoad(_ rowid: String) {
        var levelList = [String]()
        let rid = Int(rowid) ?? 0
        for i in stride(from: rid, through: 1, by: -1) {
            let idx = i - 1
            if idx < levelCache.count, let lc = levelCache[idx].asString {
                levelList.append(lc)
            }
        }
        glob.PLAYER.game_manager.setGame(.list(LingoList(levelList.map { .string($0) })))
        // current_level is accessed via LV glob; stub this side-effect
        _ = levelList.first
    }

    func load(_ rowid: Int) {
        if localmode {
            let _ = getPref(localprefix + String(rowid))
            alert("Level loaded")
        } else {
            if !netids.isEmpty { return }
            var params = PropList()
            params["mode"] = .string("load")
            params["rowid"] = .int(rowid)
            params["database"] = .string(database)
            let nid = postNetText(cgi, params)
            netids.append([nid, .string("load"), .int(rowid)])
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
            var params = PropList()
            params["mode"] = .string("load")
            params["rowid"] = .string("all")
            params["database"] = .string(database)
            let nid = postNetText(cgi, params)
            netids.append([nid, .string("catalog")])
            cattext?.text = ""
        }
    }

    func save() {
        if localmode {
            catalog()
            var entries: LingoList
            if let el = localcatalog["Entry"].asList {
                entries = el
            } else {
                entries = LingoList()
            }
            var newEntry = PropList()
            newEntry["name"] = .string(member("catalog name").text ?? "")
            newEntry["title"] = .string(member("catalog title").text ?? "")
            newEntry["comment"] = .string(member("catalog comment").text ?? "")
            entries.add(.propList(newEntry))
            localcatalog["Entry"] = .list(entries)
            var t = ""
            for i in 1...max(1, entries.count) {
                if let e = entries[i].asPropList {
                    t += "[Entry \(i)]\n"
                    t += "Name=\(e["name"].asString ?? "")\n"
                    t += "Title=\(e["title"].asString ?? "")\n"
                    t += "Comment=\(e["comment"].asString ?? "")\n"
                    t += "\n"
                }
            }
            setPref(localprefix + "cat", t)
            // current_level unavailable via LV dynamic lookup
            setPref(localprefix + String(entries.count), "")
            do_catalog_2(t)
        } else {
            if !netids.isEmpty { return }
            var params = PropList()
            params["mode"] = .string("save")
            params["name"] = .string(member("catalog name").text ?? "")
            params["title"] = .string(member("catalog title").text ?? "")
            params["comment"] = .string(member("catalog comment").text ?? "")
            params["level"] = .string("")
            params["database"] = .string(database)
            let nid = postNetText(cgi, params)
            netids.append([nid, .string("save")])
        }
    }

    func do_catalog(_ nid: LV) {
        let t = netTextResult(nid)
        do_catalog_2(t)
    }

    func do_catalog_2(_ t: String) {
        var rawlevels = [Int: String]()
        var clevel: Int? = nil
        let lines = t.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
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
            let rlLines = rl.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let line1 = rlLines.count > 0 ? rlLines[0] : ""
            let line2 = rlLines.count > 1 ? rlLines[1] : ""
            let line3 = rlLines.count > 2 ? rlLines[2] : ""
            menutext += "\(line2) by \(line1) (\(line3) )\n"
            while levelTitles.count < entrynum { levelTitles.append(.void) }
            levelTitles[entrynum - 1] = .string(line2)
            let remaining = rlLines.dropFirst(4).joined(separator: "\n")
            while levelCache.count < entrynum { levelCache.append(.void) }
            levelCache[entrynum - 1] = .string(remaining)
        }
        if menutext.hasSuffix("\n") { menutext.removeLast() }
        cattext?.text = menutext
        let menuLines = menutext.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for (i, _) in menuLines.enumerated() {
            let hl = String(hyperlinkID.count > i ? hyperlinkID[i] : 0)
            // cattext?.setHyperlink(hl, forLine: i + 1) -- stub
        }
    }

    func prepareCache(_ hyperlinkID: [Int]) {
        for id in hyperlinkID {
            if id > levelCache.count {
                idToBeCached.append(id)
                continue
            }
            if levelCache[id - 1].isString == false {
                idToBeCached.append(id)
            }
        }
    }

    func do_save(_ nid: LV) {
        catalog()
    }

    func do_load(_ nid: LV, rowid: Int) {
        let t = netTextResult(nid)
        while levelCache.count < rowid { levelCache.append(.void) }
        levelCache[rowid - 1] = .string(t)
    }

    func stepFrame() {
        if netids.isEmpty {
            sendAllSprites("netReady", .int(1))
            return
        }
        sendAllSprites("netReady", .int(0))
        var streamsofar = 0
        var streamtotal = 0
        var toRemove = [Int]()
        for (idx, nid) in netids.enumerated() {
            let ss = getStreamStatus(nid[0].asString ?? "")
            streamsofar += ss["bytesSoFar"].asInt ?? 0
            streamtotal += ss["bytesTotal"].asInt ?? 0
            let nidType = nid[1].asString ?? ""
            if nidType == "catalog" {
                cattext?.text = "Loading \(streamsofar) of about 200,000"
            }
            if netDone(nid[0]) {
                toRemove.append(idx)
                switch nidType {
                case "load":
                    do_load(nid[0], rowid: nid[2].asInt ?? 0)
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
            debugLog("caching \(id)")
        }
    }
}
