// Translated from Lingo: behavior_HOF_display behavior.ls

class BehaviorHOFDisplay: LingoObject, @unchecked Sendable {
    var ready: Int = 0
    var page: Int = 1

    // Original Lingo body: beginsprite
    // ```lingo
    // on beginSprite me
    //   glob.database_manager.loadHallOfFame()
    //   READY = 0
    //   member("HOF_rank").text = EMPTY
    //   member("HOF_names").text = RETURN & "LOADING" & RETURN
    //   member("HOF_moves").text = EMPTY
    //   page = 1
    // end
    // ```
    func beginSprite() {
        (Glob.shared["database_manager"]).loadHallOfFame()
        ready = 0
        member("HOF_rank")?.text = ""
        member("HOF_names")?.text = "\nLOADING\n"
        member("HOF_moves")?.text = ""
        page = 1
    }

    // Original Lingo body: prepareframe
    // ```lingo
    // on prepareFrame me
    //   if not READY then
    //     READY = me.displayhof()
    //   end if
    // end
    // ```
    func prepareFrame() {
        if ready == 0 {
            ready = displayhof()
        }
    }

    // Original Lingo body: pagep
    // ```lingo
    // on pageP me, a
    //   if not glob.database_manager.hofReady() then
    //     return 0
    //   end if
    //   case a of
    //     #prev:
    //       return page > 1
    //     #next:
    //       return page < 8
    //   end case
    // end
    // ```
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

    // Original Lingo body: page
    // ```lingo
    // on page me, a
    //   if not me.pageP(a) then
    //     return 
    //   end if
    //   case a of
    //     #prev:
    //       page = page - 1
    //     #next:
    //       page = page + 1
    //   end case
    //   me.displayhof()
    // end
    // ```
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
    // Original Lingo body: displayhof
    // ```lingo
    // on displayhof me
    //   if glob.database_manager.hofReady() then
    //     hof = glob.database_manager.getHallOfFame()
    //     ranks = EMPTY
    //     names = EMPTY
    //     moves = EMPTY
    //     Start = 1 + ((page - 1) * 13)
    //     finish = Start + 12
    //     if finish > 100 then
    //       finish = 100
    //     end if
    //     repeat with i = Start to finish
    //       ranks = ranks & i & "." & RETURN
    //       namekey = symbol("u" & i)
    //       movekey = symbol("t" & i)
    //       names = names & hof[namekey] & RETURN
    //       moves = moves & hof[movekey] & RETURN
    //     end repeat
    //     member("HOF_rank").text = ranks
    //     member("HOF_moves").text = moves
    //     member("HOF_names").text = names
    //     return 1
    //   else
    //     return 0
    //   end if
    // end
    // ```
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
            member("HOF_rank")?.text = ranks
            member("HOF_moves")?.text = moves
            member("HOF_names")?.text = names
            return 1
        } else {
            return 0
        }
    }
}
