// Translated from Lingo: parent_database manager.ls

import Foundation

class DatabaseManager {
    var state: [String: Any] = [:]
    var rank: [String: Any]? = nil
    var hallOfFame: [String: Any]? = nil
    var loggedin: Int? = nil
    var user_name: String? = nil
    var netID: Any? = nil
    var hofnetID: Any? = nil
    var site: String = ""
    var prefix: String = "/build/junkbot/"
    var suffix: String = ".asp"

    // Reference to global state (injected externally)
    var glob: [String: Any] = [:]

    init() {
        netID = nil
        hofnetID = nil
        loggedin = nil
        site = ""
        prefix = "/build/junkbot/"
        suffix = ".asp"
        // (the actorList).add(me)
    }

    func done() {
        // (the actorList).deleteOne(me)
    }

    func READY() -> Bool {
        return netID == nil
    }

    func getState() {
        // netID = getNetText(site + prefix + "getState" + suffix)
        // Stub: initiate network request
    }

    func setState() {
        // netID = postNetText(site + prefix + "setState" + suffix, state)
        // Stub: post state to server
    }

    func setRecord(info: [String: Any]) {
        guard loggedin == 1 else { return }
        if var rankdata = glob["rankdata"] as? [String: Any] {
            rankdata["serverState"] = "network"
            glob["rankdata"] = rankdata
        }
        state["total"] = info["total"]
        state["state"] = info["state"]
        state["record"] = info["record"]
        state["userName"] = user_name
        let timestamp = "\(Date())"
        let checkvalue = "\(info["record"] ?? "") \(user_name ?? "") \(info["total"] ?? "") \(info["state"] ?? "") \(timestamp)"
        let checksum = checksumString(checkvalue)
        state["time"] = "\(timestamp) \(checksum)"
        setState()
    }

    func getRecord() -> [String: Any]? {
        guard loggedin == 1 else { return nil }
        if var rankdata = glob["rankdata"] as? [String: Any] {
            rankdata["serverState"] = "network"
            glob["rankdata"] = rankdata
        }
        var info: [String: Any] = [:]
        info["total"] = state["total"]
        info["state"] = state["state"]
        info["record"] = state["record"]
        return info
    }

    func hofReady() -> Bool {
        return hofnetID == nil
    }

    func loadHallOfFame(callbackobject: Any?, callbackhandler: String?) {
        guard hofReady() else { return }
        // hofnetID = getNetText(site + prefix + "getTopTen" + suffix)
        // Stub: initiate network request
    }

    func getHallOfFame() -> [String: Any]? {
        return hallOfFame
    }

    /// Called once per frame by the actor list to process pending network results.
    func stepFrame() {
        // Process main netID
        if netID != nil {
            // if netDone(netID):
            //   t = netTextResult(netID)
            //   answer = decodeMulti(t)
            //   netID = nil
            //   handle rank / state / notloggedin answers
            // else if netError(netID) != "":
            //   netID = nil
            // Stub: async network completion handled externally
        }

        // Process hall-of-fame netID
        if hofnetID != nil {
            // if netDone(hofnetID):
            //   t = netTextResult(hofnetID)
            //   hofnetID = nil
            //   hallOfFame = decodeMulti(t)
            // Stub: async network completion handled externally
        }
    }

    /// Decode an HTTP query-string response ("key=value&key=value...") into a dictionary.
    func decodeMulti(_ s: String) -> [String: String] {
        var ret: [String: String] = [:]
        let pairs = s.components(separatedBy: "&")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            guard parts.count >= 1 else { continue }
            let k = parts[0]
            if k.isEmpty { continue }
            let v = parts.dropFirst().joined(separator: "=")
            ret[k] = v
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
}
