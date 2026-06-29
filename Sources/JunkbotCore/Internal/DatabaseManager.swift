// Translated from Lingo: parent_database manager.ls

class DatabaseManager: BehaviorBase {
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

    func done() {
        // (the actorList).deleteOne(me)
    }

    func READY() -> Bool {
        return netID.isVoid
    }

    func getState() {
        // netID = getNetText(site + prefix + "getState" + suffix)
        // Stub: initiate network request
    }

    func setState() {
        // netID = postNetText(site + prefix + "setState" + suffix, state)
        // Stub: post state to server
    }

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

    func getRecord() -> PropList? {
        guard loggedin == 1 else { return nil }
        if let rankdata = Glob.shared["rankdata"].asPropList {
            rankdata["serverState"] = .string("network")
        }
        let info = PropList()
        info["total"] = state["total"]
        info["state"] = state["state"]
        info["record"] = state["record"]
        return info
    }

    func hofReady() -> Bool {
        return hofnetID.isVoid
    }

    func loadHallOfFame() {
        guard hofReady() else { return }
        // hofnetID = getNetText(site + prefix + "getTopTen" + suffix)
        // Stub: initiate network request
    }

    func getHallOfFame() -> PropList? {
        return hallOfFame
    }

    /// Called once per frame by the actor list to process pending network results.
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
    func decodeMulti(_ s: String) -> PropList {
        let ret = PropList()
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
