// Translated from Lingo: behavior_legoparts manager.ls

import Foundation

class BehaviorLegopartsManager {
    var piecedata: [String: [String: Any]] = [:]

    init() {
        setPieceData()
        for key in piecedata.keys {
            if key == "end" { break }
            _ = getPieceSize(key)
        }
    }

    func setPieceData() {
        piecedata = [
            "BRICK_01": ["color": 1, "state": 0, "frame": 0, "shape": [[0, 0]]],
            "BRICK_02": ["color": 1, "state": 0, "frame": 0, "shape": [[0, 0], [1, 0]]],
            "BRICK_03": ["color": 1, "state": 0, "frame": 0, "shape": [[0, 0], [1, 0], [2, 0]]],
            "BRICK_04": ["color": 1, "state": 0, "frame": 0, "shape": [[0, 0], [1, 0], [2, 0], [3, 0]]],
            "BRICK_06": ["color": 1, "state": 0, "frame": 0, "shape": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [5, 0]]],
            "BRICK_08": ["color": 1, "state": 0, "frame": 0, "shape": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0], [7, 0]]],
            "flag": ["color": 1, "state": 0, "frame": 0, "shape": [[0, 0], [1, 0], [0, -1], [1, -1], [0, -2], [1, -2]]],
            "WHEEL04": ["color": 0, "state": 0, "frame": 0, "shape": [[0, 0], [1, 0], [2, 0], [3, 0], [0, -1], [1, -1], [2, -1], [3, -1], [0, -2], [1, -2], [2, -2], [3, -2]]],
            "MINIFIG": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0], [0, -1], [1, -1], [0, -2], [1, -2], [0, -3], [1, -3]]],
            "HAZ_FLOAT": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0], [0, -1], [1, -1]]],
            "HAZ_DUMBFLOAT": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0], [0, -1], [1, -1]]],
            "haz_walker": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0], [0, -1], [1, -1]]],
            "HAZ_CLIMBER": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0], [0, -1], [1, -1]]],
            "HAZ_SLICKFIRE": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0], [2, 0], [3, 0]]],
            "HAZ_SLICKFAN": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0], [2, 0], [3, 0]]],
            "haz_slickJump": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0]]],
            "BRICK_SLICKJUMP": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0]]],
            "HAZ_SLICKPIPE": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0]]],
            "HAZ_SLICKSWITCH": ["color": 0, "state": 1, "frame": 1, "shape": [[0, 0], [1, 0]]],
            "HAZ_SLICKSHIELD": ["color": 0, "state": 0, "frame": 0, "shape": [[0, 0], [1, 0]]],
            "end": [:]
        ]
    }

    func getPieceShape(_ typ: String) -> [[Int]] {
        return (piecedata[typ]?["shape"] as? [[Int]]) ?? []
    }

    @discardableResult
    func getPieceSize(_ typ: String) -> [Int] {
        guard var data = piecedata[typ] else { return [0, 0] }
        if data["size"] == nil {
            let shape = (data["shape"] as? [[Int]]) ?? []
            var smin = [0, 0]
            var smax = [0, 0]
            for s in shape {
                for i in 0..<2 {
                    if s[i] < smin[i] { smin[i] = s[i] }
                    if s[i] > smax[i] { smax[i] = s[i] }
                }
            }
            let size = [smax[0] - smin[0] + 1, smax[1] - smin[1] + 1]
            data["size"] = size
            data["split"] = size[1] > 1
            piecedata[typ] = data
        }
        return (data["size"] as? [Int]) ?? [0, 0]
    }

    /// Build the member name string for a part.
    /// - Parameters:
    ///   - part: a dictionary with keys "type", "color", "state", "frame"
    ///   - single: pass "single" to get a single name string; otherwise returns list of names
    ///   - glob: global settings dict (needs "split_tall_members")
    func getPieceMemberName(part: [String: Any], single: String, glob: [String: Any]) -> Any {
        guard let typ = part["type"] as? String else { return "" }
        var m = typ
        guard let data = piecedata[typ] else { return [m] }

        if (data["color"] as? Int) == 1 {
            m += "_\(part["color"] ?? "")"
        }
        if (data["state"] as? Int) == 1 {
            m += "_\(part["state"] ?? "")"
        }
        if (data["frame"] as? Int) == 1 {
            m += "_\(part["frame"] ?? "")"
        }

        if single == "single" {
            return m
        }

        if (glob["split_tall_members"] as? Int) != 1 {
            return [m]
        }

        let split = (data["split"] as? Bool) ?? false
        let size = (data["size"] as? [Int]) ?? [1, 1]
        if split {
            var ret: [String] = []
            for s in 1...size[1] {
                ret.append(m + "_s\(s)")
            }
            // If member(ret[0]) doesn't exist, would call splitTallMember
            return ret
        } else {
            return [m]
        }
    }

    /// Split a tall member image into per-row sub-members.
    func splitTallMember(typ: String, basename: String, splitnames: [String]) {
        guard let data = piecedata[typ] else { return }
        let stack = (data["size"] as? [Int])?[1] ?? 1
        let dy = 18
        // Stub: image splitting would be performed using platform image APIs
        // For each slice i in 1...stack:
        //   ih = (i < stack) ? dy : h - ((stack - 1) * dy)
        //   Create image slice, assign to new bitmap member named splitnames[i-1]
        //   Set regPoint accordingly
        _ = stack
        _ = dy
        print("splitTallMember: \(basename) into \(splitnames)")
    }
}
