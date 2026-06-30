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

  // Original Lingo body: new
  // ```lingo
  // on new me
  //   localmode = (the environment).internetConnected = #offline
  //   database = "alpha"
  //   levelCache = []
  //   levelTitles = []
  //   netids = []
  //   cgi = "http://www.urth.net/lego_db/levels.cgi"
  //   localprefix = "lego"
  //   cattext = member("catalog text")
  //   add(the actorList, me)
  //   idToBeCached = []
  //   return me
  // end
  // ```
  override init() {
    super.init()
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

  // Original Lingo body: clickload
  // ```lingo
  // on clickLoad me, rowid
  //   levelList = []
  //   repeat with i = integer(rowid) down to 1
  //     if levelCache[i] = 0 then
  //       next repeat
  //     end if
  //     levelList.add(levelCache[i])
  //   end repeat
  //   glob.PLAYER.game_manager.setGame(levelList)
  //   glob.EDITOR.edit_manager.playfield_manager.current_level = levelList[1]
  // end
  // ```
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
        _ = levelList.first
  }

  // Original Lingo body: load
  // ```lingo
  // on load me, rowid
  //   if localmode then
  //     t = getPref(localprefix & rowid)
  //     alert("Level loaded")
  //   else
  //     if netids.count > 0 then
  //       return
  //     end if
  //     nid = postNetText(cgi, [#mode: "load", #rowid: rowid, #database: database])
  //     netids.add([nid, #load, rowid])
  //   end if
  // end
  // ```
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

  // Original Lingo body: catalog
  // ```lingo
  // on catalog me
  //   if localmode then
  //     t = getPref(localprefix & "cat")
  //     if t = VOID then
  //       t = EMPTY
  //       setPref(localprefix & "cat", t)
  //     end if
  //     me.do_catalog_2(t)
  //   else
  //     if netids.count > 0 then
  //       return
  //     end if
  //     nid = postNetText(cgi, [#mode: "load", #rowid: "all", #database: database])
  //     netids.add([nid, #catalog])
  //     cattext.text = EMPTY
  //   end if
  // end
  // ```
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

  // Original Lingo body: save
  // ```lingo
  // on save me
  //   if localmode then
  //     me.catalog()
  //     localcatalog.Entry.add([#name: member("catalog name").text, #title: member("catalog title").text, #comment: member("catalog comment").text])
  //     t = EMPTY
  //     repeat with i = 1 to localcatalog.Entry.count
  //       e = localcatalog.Entry[i]
  //       t = t & "[Entry " & i & "]" & RETURN
  //       t = t & "Name=" & e.name & RETURN
  //       t = t & "Title=" & e.title & RETURN
  //       t = t & "Comment=" & e.comment & RETURN
  //       t = t & RETURN
  //     end repeat
  //     setPref(localprefix & "cat", t)
  //     setPref(localprefix & localcatalog.Entry.count, glob.EDITOR.edit_manager.playfield_manager.current_level)
  //     me.do_catalog_2(t)
  //   else
  //     if netids.count > 0 then
  //       return
  //     end if
  //     nid = postNetText(cgi, [#mode: "save", #name: member("catalog name").text, #title: member("catalog title").text, #comment: member("catalog comment").text, #level: glob.EDITOR.edit_manager.playfield_manager.current_level, #database: database])
  //     netids.add([nid, #save])
  //   end if
  // end
  // ```
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
      newEntry["name"] = .string(member("catalog name")?.text ?? "")
      newEntry["title"] = .string(member("catalog title")?.text ?? "")
      newEntry["comment"] = .string(member("catalog comment")?.text ?? "")
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
      params["name"] = .string(member("catalog name")?.text ?? "")
      params["title"] = .string(member("catalog title")?.text ?? "")
      params["comment"] = .string(member("catalog comment")?.text ?? "")
      params["level"] = .string("")
      params["database"] = .string(database)
      let nid = postNetText(cgi, params)
      netids.append([nid, .string("save")])
    }
  }

  // Original Lingo body: do_catalog
  // ```lingo
  // on do_catalog me, nid
  //   t = netTextResult(nid)
  //   me.do_catalog_2(t)
  // end
  // ```
  func do_catalog(_ nid: LV) {
    let t = netTextResult(nid)
    do_catalog_2(t)
  }

  // Original Lingo body: do_catalog_2
  // ```lingo
  // on do_catalog_2 me, t
  //   rawlevels = []
  //   clevel = VOID
  //   nlt = the number of lines in t
  //   repeat with ln = 1 to nlt
  //     L = line ln of t
  //     if word 1 of L = "<<<<" then
  //       clevel = integer(word 2 of L)
  //       rawlevels[clevel] = EMPTY
  //     else
  //       if not voidp(clevel) then
  //         rawlevels[clevel] = rawlevels[clevel] & L & RETURN
  //       end if
  //     end if
  //     if (ln mod 100) = 0 then
  //       cattext.text = "Scanning" && ln && "of" && nlt
  //       updateStage()
  //     end if
  //   end repeat
  //   menutext = EMPTY
  //   hyperlinkID = []
  //   repeat with entrynum = rawlevels.count down to 1
  //     rl = rawlevels[entrynum]
  //     if rl = 0 then
  //       next repeat
  //     end if
  //     hyperlinkID.add(entrynum)
  //     menutext = menutext & line 2 of rl && "by" && line 1 of rl && "(" & line 3 of rl && ")" & RETURN
  //     levelTitles[entrynum] = line 2 of rl
  //     delete line 1 to 4 of rl
  //     levelCache[entrynum] = rl
  //   end repeat
  //   delete char -30000 of menutext
  //   cattext.text = menutext
  //   i = 0
  //   repeat with i = 1 to the number of lines in the text of cattext
  //     hl = string(hyperlinkID[i])
  //     member(cattext).line[i].Hyperlink = hl
  //   end repeat
  // end
  // ```
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
    let menuLines = menutext.split(separator: "\n", omittingEmptySubsequences: false).map(
      String.init)
    for (i, _) in menuLines.enumerated() {
      let hl = String(hyperlinkID.count > i ? hyperlinkID[i] : 0)
          }
  }

  // Original Lingo body: preparecache
  // ```lingo
  // on prepareCache me, hyperlinkID
  //   repeat with id in hyperlinkID
  //     if id > levelCache.count then
  //       idToBeCached.add(id)
  //       next repeat
  //     end if
  //     if not (ilk(levelCache[id]) = #string) then
  //       idToBeCached.add(id)
  //     end if
  //   end repeat
  // end
  // ```
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

  // Original Lingo body: do_save
  // ```lingo
  // on do_save me, nid
  //   me.catalog()
  // end
  // ```
  func do_save(_ nid: LV) {
    catalog()
  }

  // Original Lingo body: do_load
  // ```lingo
  // on do_load me, nid, rowid
  //   t = netTextResult(nid)
  //   levelCache[rowid] = t
  // end
  // ```
  func do_load(_ nid: LV, rowid: Int) {
    let t = netTextResult(nid)
    while levelCache.count < rowid { levelCache.append(.void) }
    levelCache[rowid - 1] = .string(t)
  }

  // Original Lingo body: stepframe
  // ```lingo
  // on stepFrame me
  //   if netids.count = 0 then
  //     sendAllSprites(#netReady, 1)
  //     return
  //   end if
  //   sendAllSprites(#netReady, 0)
  //   streamsofar = 0
  //   streamtotal = 0
  //   repeat with nid in netids
  //     ss = getStreamStatus(nid[1])
  //     streamsofar = streamsofar + ss.bytesSoFar
  //     streamtotal = streamtotal + ss.bytesTotal
  //     if nid[2] = #catalog then
  //       cattext.text = "Loading" && streamsofar && "of about 200,000"
  //     end if
  //     if netDone(nid[1]) then
  //       netids.deleteOne(nid)
  //       case nid[2] of
  //         #load:
  //           me.do_load(nid[1], nid[3])
  //         #catalog:
  //           me.do_catalog(nid[1])
  //         #save:
  //           me.do_save(nid[1])
  //       end case
  //     end if
  //   end repeat
  //   if (netids.count = 0) and (idToBeCached.count > 0) then
  //     id = idToBeCached[1]
  //     idToBeCached.deleteAt(1)
  //     me.load(id)
  //     put "caching" && id
  //   end if
  // end
  // ```
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
