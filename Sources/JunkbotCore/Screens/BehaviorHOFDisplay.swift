// Translated from Lingo: behavior_HOF_display behavior.ls

class BehaviorHOFDisplay {
    var ready: Int = 0
    var page: Int = 1

    func beginSprite() {
        (Glob.shared["database_manager"]).loadHallOfFame()
        ready = 0
        member("HOF_rank").text = ""
        member("HOF_names").text = "\nLOADING\n"
        member("HOF_moves").text = ""
        page = 1
    }

    func prepareFrame() {
        if ready == 0 {
            ready = displayhof()
        }
    }

    func pageP(_ a: String) -> Int {
        if (Glob.shared["database_manager"]).hofReady() == 0 {
            return 0
        }
        switch a {
        case "prev":
            return page > 1 ? 1 : 0
        case "next":
            return page < 8 ? 1 : 0
        default:
            return 0
        }
    }

    func page(_ a: String) {
        if pageP(a) == 0 {
            return
        }
        switch a {
        case "prev":
            page -= 1
        case "next":
            page += 1
        default:
            break
        }
        let _ = displayhof()
    }

    @discardableResult
    func displayhof() -> Int {
        if (Glob.shared["database_manager"]).hofReady().asInt ?? 0 != 0 {
            let hof = (Glob.shared["database_manager"]).getHallOfFame().asPropList!
            var ranks = ""
            var names = ""
            var moves = ""
            let start = 1 + ((page - 1) * 13)
            var finish = start + 12
            if finish > 100 {
                finish = 100
            }
            for i in start...finish {
                ranks = ranks + "\(i).\n"
                let namekey = "u\(i)"
                let movekey = "t\(i)"
                names = names + (hof[namekey].asString ?? "") + "\n"
                moves = moves + (hof[movekey].asString ?? "") + "\n"
            }
            member("HOF_rank").text = ranks
            member("HOF_moves").text = moves
            member("HOF_names").text = names
            return 1
        } else {
            return 0
        }
    }
}
