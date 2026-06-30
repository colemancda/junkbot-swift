// Translated from Lingo: parent_database manager.ls

class DatabaseManager: LingoObject, @unchecked Sendable {
    var state: PropList = PropList()
    var rank: PropList? = nil
    var hallOfFame: PropList? = nil
    var loggedin: Int = 0
    var user_name: String = ""
    var netID: LV = .void
    var hofnetID: LV = .void
    var site: String = ""
    var prefix: String = "/build/junkbot/"
    var suffix: String = ".asp"

    // Original Lingo body: new
    // ```lingo
    // on new me
    //   userID = VOID
    //   netID = VOID
    //   hofnetID = VOID
    //   loggedin = VOID
    //   site = EMPTY
    //   prefix = "/build/junkbot/"
    //   suffix = ".asp"
    //   (the actorList).add(me)
    //   return me
    // end
    // ```
    override init() {
        super.init()
        netID = .void
        hofnetID = .void
        loggedin = 0
        site = ""
        prefix = "/build/junkbot/"
        suffix = ".asp"
        // (the actorList).add(me)
    }

    // Original Lingo body: done
    // ```lingo
    // on done me
    //   (the actorList).deleteOne(me)
    // end
    // ```
    func done() {
        // (the actorList).deleteOne(me)
    }

    // Original Lingo body: ready
    // ```lingo
    // on READY me
    //   return voidp(netID)
    // end
    // ```
    func READY() -> Bool {
        return netID.isVoid
    }

    // Original Lingo body: getstate
    // ```lingo
    // on getState me
    //   netID = getNetText(site & prefix & "getState" & suffix)
    // end
    // ```
    func getState() {
        // netID = getNetText(site + prefix + "getState" + suffix)
        // Stub: initiate network request
    }

    // Original Lingo body: setstate
    // ```lingo
    // on setState me
    //   netID = postNetText(site & prefix & "setState" & suffix, state)
    // end
    // ```
    func setState() {
        // netID = postNetText(site + prefix + "setState" + suffix, state)
        // Stub: post state to server
    }

    // Original Lingo body: setrecord
    // ```lingo
    // on setRecord me, info
    //   if loggedin <> 1 then
    //     return VOID
    //   end if
    //   glob[#rankdata][#serverState] = #network
    //   state[#total] = info[#total]
    //   state[#state] = info[#state]
    //   state[#record] = info[#record]
    //   state[#userName] = user_name
    //   timestamp = the date && the time
    //   checkvalue = info[#record] && user_name && info[#total] && info[#state] && timestamp
    //   checksum = me.checksumString(checkvalue)
    //   state[#time] = timestamp && checksum
    //   me.setState()
    // end
    // ```
    func setRecord(info: PropList) {
        guard loggedin == 1 else { return }
        if let rankdata = Glob.shared["rankdata"].asPropList {
            rankdata["serverState"] = .string("network")
        }
        state["total"] = info["total"]
        state["state"] = info["state"]
        state["record"] = info["record"]
        state["userName"] = .string(user_name)
        let timestamp = "\(currentMilliseconds)"
        let checkvalue = "\(info["record"].asString ?? "") \(user_name) \(info["total"].asString ?? "") \(info["state"].asString ?? "") \(timestamp)"
        let checksum = checksumString(checkvalue)
        state["time"] = .string("\(timestamp) \(checksum)")
        setState()
    }

    // Original Lingo body: getrecord
    // ```lingo
    // on getRecord me
    //   if loggedin <> 1 then
    //     return VOID
    //   end if
    //   glob[#rankdata][#serverState] = #network
    //   info = [:]
    //   info[#total] = state[#total]
    //   info[#state] = state[#state]
    //   info[#record] = state[#record]
    //   return info
    // end
    // ```
    func getRecord() -> PropList? {
        guard loggedin == 1 else { return nil }
        if let rankdata = Glob.shared["rankdata"].asPropList {
            rankdata["serverState"] = .string("network")
        }
        var info = PropList()
        info["total"] = state["total"]
        info["state"] = state["state"]
        info["record"] = state["record"]
        return info
    }

    // Original Lingo body: hofready
    // ```lingo
    // on hofReady me
    //   return voidp(hofnetID)
    // end
    // ```
    func hofReady() -> Bool {
        return hofnetID.isVoid
    }

    // Original Lingo body: loadhalloffame
    // ```lingo
    // on loadHallOfFame me, callbackobject, callbackhandler
    //   if not me.hofReady() then
    //     return 
    //   end if
    //   hofnetID = getNetText(site & prefix & "getTopTen" & suffix)
    // end
    // ```
    func loadHallOfFame() {
        guard hofReady() else { return }
        // hofnetID = getNetText(site + prefix + "getTopTen" + suffix)
        // Stub: initiate network request
    }

    // Original Lingo body: gethalloffame
    // ```lingo
    // on getHallOfFame me
    //   return hallOfFame
    // end
    // ```
    func getHallOfFame() -> PropList? {
        return hallOfFame
    }

    /// Called once per frame by the actor list to process pending network results.
    // Original Lingo body: stepframe
    // ```lingo
    // on stepFrame me
    //   if not voidp(netID) then
    //     if netDone(netID) then
    //       t = netTextResult(netID)
    //       answer = me.decodeMulti(t)
    //       netID = VOID
    //       if not voidp(answer[#rank]) then
    //         rank = answer
    //         rank[#rank] = integer(rank[#rank])
    //         rank[#outof] = integer(rank[#outof])
    //         if not voidp(rank[#outof]) then
    //           glob[#rankdata][#rank] = rank.rank
    //           glob[#rankdata][#players] = rank.outof
    //           glob[#rankdata][#serverState] = #READY
    //         end if
    //         loggedin = 1
    //       end if
    //       if not voidp(answer[#userID]) then
    //         state = answer
    //         state.state = integer(state.state)
    //         state.total = integer(state.total)
    //         user_name = answer.userName
    //         site = "http://" & answer.domainname
    //         loggedin = 1
    //       end if
    //       if not voidp(answer[#notloggedin]) then
    //         loggedin = 0
    //       end if
    //     else
    //       if netError(netID) <> EMPTY then
    //         netID = VOID
    //       end if
    //     end if
    //   end if
    //   if not voidp(hofnetID) then
    //     if netDone(hofnetID) then
    //       t = netTextResult(hofnetID)
    //       hofnetID = VOID
    //       hallOfFame = me.decodeMulti(t)
    //     else
    //     end if
    //   end if
    // end
    // ```
    func stepFrame() {
        // Process main netID
        if !netID.isVoid {
            // if netDone(netID):
            //   t = netTextResult(netID)
            //   answer = decodeMulti(t)
            //   netID = .void
            //   handle rank / state / notloggedin answers
            // else if netError(netID) != "":
            //   netID = .void
            // Stub: async network completion handled externally
        }

        // Process hall-of-fame netID
        if !hofnetID.isVoid {
            // if netDone(hofnetID):
            //   t = netTextResult(hofnetID)
            //   hofnetID = .void
            //   hallOfFame = decodeMulti(t)
            // Stub: async network completion handled externally
        }
    }

    /// Decode an HTTP query-string response ("key=value&key=value...") into a prop list.
    // Original Lingo body: decodemulti
    // ```lingo
    // on decodeMulti me, s
    //   pairs = []
    //   tid = the itemDelimiter
    //   the itemDelimiter = "&"
    //   repeat with p = 1 to s.item.count
    //     pairs.add(s.item[p])
    //   end repeat
    //   ret = [:]
    //   the itemDelimiter = "="
    //   repeat with p in pairs
    //     if p.item[1] = EMPTY then
    //       next repeat
    //     end if
    //     k = symbol(p.item[1])
    //     if k = VOID then
    //       next repeat
    //     end if
    //     delete item 1 of p
    //     ret.addProp(k, p)
    //   end repeat
    //   the itemDelimiter = tid
    //   return ret
    // end
    // ```
    func decodeMulti(_ s: String) -> PropList {
        var ret = PropList()
        let pairs = splitOn(s, sep: "&")
        for pair in pairs {
            let parts = splitOn(pair, sep: "=")
            guard !parts.isEmpty else { continue }
            let k = parts[0]
            if k.isEmpty { continue }
            let v = parts.dropFirst().joined(separator: "=")
            ret[k] = .string(v)
        }
        return ret
    }

    /// Simple rolling checksum over a string.
    // Original Lingo body: checksumstring
    // ```lingo
    // on checksumString me, s
    //   sum = 0
    //   m = (s.length mod 113) + 1
    //   repeat with n = 1 to s.length
    //     c = charToNum(s.char[n])
    //     a = (c * m mod 355) + 1
    //     m = ((m + a) mod 113) + 1
    //     sum = (sum + a) mod 94113
    //   end repeat
    //   return sum
    // end
    // ```
    func checksumString(_ s: String) -> Int {
        var sum = 0
        var m = (s.count % 113) + 1
        for char in s.unicodeScalars {
            let c = Int(char.value)
            let a = (c * m % 355) + 1
            m = ((m + a) % 113) + 1
            sum = (sum + a) % 94113
        }
        return sum
    }

    // MARK: - String helpers

    func splitOn(_ s: String, sep: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        for c in s {
            if c == sep {
                parts.append(current)
                current = ""
            } else {
                current.append(c)
            }
        }
        parts.append(current)
        return parts
    }
}
