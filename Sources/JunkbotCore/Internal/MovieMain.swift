// Translated from Lingo: movie_main.ls

var version: String = ""

func prepareMovie() {
    // the actorList = []
    // the itemDelimiter = ","
    let g = Glob.shared
    g["EDITOR"] = .propList(PropList())
    g["catalog"] = .propList(PropList())
    g["PLAYER"] = .propList(PropList())
    g["config_manager"] = .void  // BehaviorConfigManager instance stored externally
    g["legoparts_manager"] = .void  // BehaviorLegopartsManager instance stored externally
    g["database_manager"] = .void  // DatabaseManager instance stored externally
    initSound()
    g["authorMode"] = .int(0)
    g["split_tall_members"] = .int(1)
    // put "0" into field "editor par field"
    // put "" into field "catalog title"
    // put "" into field "editor hint field"
}

func startMovie() {
    let rankdata = PropList()
    rankdata["keys"] = .int(0)
    rankdata["moves"] = .int(0)
    rankdata["rank"] = .int(0)
    rankdata["players"] = .int(0)
    Glob.shared["rankdata"] = .propList(rankdata)
    // glob.download_manager.begin()
    // glob.database_manager.getState()
}

func movieloaded() {
    // glob.PLAYER["game_manager"] = new(script("game manager"))
    // glob.EDITOR["edit_manager"] = new(script("edit manager"))
    // glob.catalog["catalog_manager"] = new(script("catalog manager"))
}

func stopMovie() {
    // the actorList = []
}

func streamStatus(url: String, bytesSoFar: Int, bytesTotal: Int) {
    // glob.download_manager.streamStatus(url, state, bytesSoFar, bytesTotal)
}

func keyDown(key: String) {
    // sendAllSprites(#equiv_keydown, key)
}

func gbutton(_ msg: String) {
    switch msg {
    case "main_edit":
        do_editor()
    case "main_play":
        do_player()
    case "main_catalog":
        do_catalog()
    default:
        break
    }
}

func do_editor() {
    // if the frame == marker("play"): glob.PLAYER.play_manager.leave()
    // go(marker("edit"))
    // glob.EDITOR.edit_manager.refresh()
}

func do_catalog() {
    // if the frame == marker("edit"): glob.EDITOR.edit_manager.leave()
    // if the frame == marker("play"): glob.PLAYER.play_manager.leave()
    // go(marker("catalog"))
    // glob.catalog.catalog_manager.catalog()
}

func do_player() {
    // if the frame == marker("edit"): glob.EDITOR.edit_manager.leave()
    // glob.PLAYER.game_manager.startGame()
}

func setCursorEffect(_ ce: String) {
    let g = Glob.shared
    if g["cursor"].isVoid {
        g["cursor"] = .propList(PropList())
    }
    if let cursor = g["cursor"].asPropList {
        cursor[ce] = .int(1)
    }
    setCursor(nil)
}

func clearCursorEffect(_ ce: String) {
    let g = Glob.shared
    if g["cursor"].isVoid {
        g["cursor"] = .propList(PropList())
    }
    if ce == "all" {
        g["cursor"] = .propList(PropList())
    } else {
        if let cursor = g["cursor"].asPropList {
            cursor[ce] = .int(0)
        }
    }
    setCursor(nil)
}

func setCursor(_ c: String?) {
    let g = Glob.shared
    if g["cursor"].isVoid {
        g["cursor"] = .propList(PropList())
    }
    if let sym = c {
        let newCursor = PropList()
        newCursor[sym] = .int(1)
        g["cursor"] = .propList(newCursor)
    }
    guard let cursor = g["cursor"].asPropList else { return }

    if cursor["text"].asInt == 1 {
        // cursor(0) — system default cursor
    } else if cursor["grab_up"].asInt == 1 {
        // cursor([member("grab_up cursor").memberNum, member("grab cursor mask").memberNum])
    } else if cursor["grab_down"].asInt == 1 {
        // cursor([member("grab_down cursor").memberNum, member("grab cursor mask").memberNum])
    } else if cursor["grab_both"].asInt == 1 {
        // cursor([member("grab_both cursor").memberNum, member("grab cursor mask").memberNum])
    } else if cursor["grabber"].asInt == 1 {
        // cursor([member("grabber cursor").memberNum, member("grabber cursor mask").memberNum])
    } else if cursor["eraser"].asInt == 1 {
        // cursor([member("eraser cursor").memberNum, member("eraser cursor mask").memberNum])
    } else {
        // cursor(0) — system default cursor
    }
}

func enterFrame() {
    debugLog("My name is Junkbot")
}

func exitFrame() {
    debugLog("I love to eat trash")
}

func prepareFrame() {
    debugLog("Junk is food!")
}

func showGlobals() {
    debugLog("version = \"8.0\"")
}
