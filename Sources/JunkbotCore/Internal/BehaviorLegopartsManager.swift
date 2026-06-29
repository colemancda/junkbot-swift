// Translated from Lingo: behavior_legoparts manager.ls

/// Per-piece data record (typed fields avoid Any).
struct PieceRecord {
    var color: Int
    var state: Int
    var frame: Int
    var shape: [[Int]]
    var size: [Int]
    var split: Bool
}

class BehaviorLegopartsManager: LingoObject {
    var piecedata: PropList = PropList()

    override init() {
        super.init()
        setPieceData()
        for i in 1...piecedata.count {
            let (key, _) = piecedata.getPropAt(i)
            if key == "end" { break }
            _ = getPieceSize(key)
        }
    }

    func makePiece(color: Int, state: Int, frame: Int, shape: [[Int]]) -> PropList {
        let p = PropList()
        p["color"] = .int(color)
        p["state"] = .int(state)
        p["frame"] = .int(frame)
        let shapeList = LingoList()
        for cell in shape {
            let pair = LingoList()
            pair.add(.int(cell[0]))
            pair.add(.int(cell[1]))
            shapeList.add(.list(pair))
        }
        p["shape"] = .list(shapeList)
        return p
    }

    func setPieceData() {
        piecedata = PropList()
        piecedata["BRICK_01"]      = .propList(makePiece(color: 1, state: 0, frame: 0, shape: [[0,0]]))
        piecedata["BRICK_02"]      = .propList(makePiece(color: 1, state: 0, frame: 0, shape: [[0,0],[1,0]]))
        piecedata["BRICK_03"]      = .propList(makePiece(color: 1, state: 0, frame: 0, shape: [[0,0],[1,0],[2,0]]))
        piecedata["BRICK_04"]      = .propList(makePiece(color: 1, state: 0, frame: 0, shape: [[0,0],[1,0],[2,0],[3,0]]))
        piecedata["BRICK_06"]      = .propList(makePiece(color: 1, state: 0, frame: 0, shape: [[0,0],[1,0],[2,0],[3,0],[4,0],[5,0]]))
        piecedata["BRICK_08"]      = .propList(makePiece(color: 1, state: 0, frame: 0, shape: [[0,0],[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0]]))
        piecedata["flag"]          = .propList(makePiece(color: 1, state: 0, frame: 0, shape: [[0,0],[1,0],[0,-1],[1,-1],[0,-2],[1,-2]]))
        piecedata["WHEEL04"]       = .propList(makePiece(color: 0, state: 0, frame: 0, shape: [[0,0],[1,0],[2,0],[3,0],[0,-1],[1,-1],[2,-1],[3,-1],[0,-2],[1,-2],[2,-2],[3,-2]]))
        piecedata["MINIFIG"]       = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0],[0,-1],[1,-1],[0,-2],[1,-2],[0,-3],[1,-3]]))
        piecedata["HAZ_FLOAT"]     = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0],[0,-1],[1,-1]]))
        piecedata["HAZ_DUMBFLOAT"] = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0],[0,-1],[1,-1]]))
        piecedata["haz_walker"]    = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0],[0,-1],[1,-1]]))
        piecedata["HAZ_CLIMBER"]   = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0],[0,-1],[1,-1]]))
        piecedata["HAZ_SLICKFIRE"] = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0],[2,0],[3,0]]))
        piecedata["HAZ_SLICKFAN"]  = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0],[2,0],[3,0]]))
        piecedata["haz_slickJump"] = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0]]))
        piecedata["BRICK_SLICKJUMP"] = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0]]))
        piecedata["HAZ_SLICKPIPE"] = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0]]))
        piecedata["HAZ_SLICKSWITCH"] = .propList(makePiece(color: 0, state: 1, frame: 1, shape: [[0,0],[1,0]]))
        piecedata["HAZ_SLICKSHIELD"] = .propList(makePiece(color: 0, state: 0, frame: 0, shape: [[0,0],[1,0]]))
        piecedata["end"]           = .propList(PropList())
    }

    func getPieceShape(_ typ: String) -> [[Int]] {
        guard let data = piecedata[typ].asPropList else { return [] }
        guard let shapeList = data["shape"].asList else { return [] }
        var result: [[Int]] = []
        for i in 1...max(1, shapeList.count) {
            guard i <= shapeList.count else { break }
            if let pair = shapeList[i].asList {
                let x = pair[1].asInt ?? 0
                let y = pair[2].asInt ?? 0
                result.append([x, y])
            }
        }
        return result
    }

    @discardableResult
    func getPieceSize(_ typ: String) -> [Int] {
        guard let data = piecedata[typ].asPropList else { return [0, 0] }
        if !data["size"].isVoid {
            let szList = data["size"].asList
            let w = szList?[1].asInt ?? 0
            let h = szList?[2].asInt ?? 0
            return [w, h]
        }
        let shape = getPieceShape(typ)
        var sminX = 0, sminY = 0, smaxX = 0, smaxY = 0
        for s in shape {
            if s[0] < sminX { sminX = s[0] }
            if s[1] < sminY { sminY = s[1] }
            if s[0] > smaxX { smaxX = s[0] }
            if s[1] > smaxY { smaxY = s[1] }
        }
        let sizeW = smaxX - sminX + 1
        let sizeH = smaxY - sminY + 1
        let sizeList = LingoList()
        sizeList.add(.int(sizeW))
        sizeList.add(.int(sizeH))
        data["size"] = .list(sizeList)
        data["split"] = .int(sizeH > 1 ? 1 : 0)
        return [sizeW, sizeH]
    }

    /// Build the member name string for a part.
    /// - Parameters:
    ///   - part: a prop list with keys "type", "color", "state", "frame"
    ///   - single: pass "single" to get a single name string; otherwise returns list of names
    func getPieceMemberName(part: PropList, single: String) -> LV {
        guard let typ = part["type"].asString else { return .string("") }
        var m = typ
        guard let data = piecedata[typ].asPropList else {
            let l = LingoList(); l.add(.string(m)); return .list(l)
        }

        if data["color"].asInt == 1 {
            m += "_\(part["color"].asString ?? "")"
        }
        if data["state"].asInt == 1 {
            m += "_\(part["state"].asString ?? "")"
        }
        if data["frame"].asInt == 1 {
            m += "_\(part["frame"].asString ?? "")"
        }

        if single == "single" {
            return .string(m)
        }

        if Glob.shared["split_tall_members"].asInt != 1 {
            let l = LingoList(); l.add(.string(m)); return .list(l)
        }

        let splitFlag = data["split"].asInt == 1
        let sz = getPieceSize(typ)
        if splitFlag {
            let ret = LingoList()
            for s in 1...max(1, sz[1]) {
                ret.add(.string(m + "_s\(s)"))
            }
            // If member(ret[0]) doesn't exist, would call splitTallMember
            return .list(ret)
        } else {
            let l = LingoList(); l.add(.string(m)); return .list(l)
        }
    }

    /// Split a tall member image into per-row sub-members.
    func splitTallMember(typ: String, basename: String, splitnames: [String]) {
        let sz = getPieceSize(typ)
        let stack = sz[1]
        let dy = 18
        // Stub: image splitting would be performed using platform image APIs
        // For each slice i in 1...stack:
        //   ih = (i < stack) ? dy : h - ((stack - 1) * dy)
        //   Create image slice, assign to new bitmap member named splitnames[i-1]
        //   Set regPoint accordingly
        _ = stack
        _ = dy
        debugLog("splitTallMember: \(basename) into \(splitnames)")
    }
}
