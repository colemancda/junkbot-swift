// Translated from Lingo: movie_main.ls

import Foundation

/// Top-level application state, mirroring the Lingo `glob` global.
var glob: [String: Any] = [:]
var version: String = ""

func prepareMovie() {
    // the actorList = []
    // the itemDelimiter = ","
    glob = [
        "EDITOR": [String: Any](),
        "catalog": [String: Any](),
        "PLAYER": [String: Any]()
    ]
    glob["config_manager"] = BehaviorConfigManager()
    // glob["download_manager"] = new(script("download manager"))
    glob["legoparts_manager"] = BehaviorLegopartsManager()
    // glob.PLAYER["play_manager"] = new(script("play manager"))
    glob["database_manager"] = DatabaseManager()
    initSound()
    glob["authorMode"] = 0
    glob["split_tall_members"] = 1
    // put "0" into field "editor par field"
    // put "" into field "catalog title"
    // put "" into field "editor hint field"
}

func startMovie() {
    var rankdata: [String: Any] = [:]
    rankdata["keys"] = 0
    rankdata["moves"] = 0
    rankdata["rank"] = 0
    rankdata["players"] = 0
    glob["rankdata"] = rankdata
    // glob.download_manager.begin()
    if let dm = glob["database_manager"] as? DatabaseManager {
        dm.getState()
    }
}

func movieloaded() {
    // glob.PLAYER["game_manager"] = new(script("game manager"))
    // glob.EDITOR["edit_manager"] = new(script("edit manager"))
    // glob.catalog["catalog_manager"] = new(script("catalog manager"))
}

func stopMovie() {
    // the actorList = []
}

func streamStatus(url: String, state: Any, bytesSoFar: Int, bytesTotal: Int, error: Any?) {
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
    if glob["cursor"] == nil {
        glob["cursor"] = [String: Any]()
    }
    if var cursor = glob["cursor"] as? [String: Any] {
        cursor[ce] = 1
        glob["cursor"] = cursor
    }
    setCursor(nil)
}

func clearCursorEffect(_ ce: String) {
    if glob["cursor"] == nil {
        glob["cursor"] = [String: Any]()
    }
    if ce == "all" {
        glob["cursor"] = [String: Any]()
    } else {
        if var cursor = glob["cursor"] as? [String: Any] {
            cursor[ce] = 0
            glob["cursor"] = cursor
        }
    }
    setCursor(nil)
}

func setCursor(_ c: String?) {
    if glob["cursor"] == nil {
        glob["cursor"] = [String: Any]()
    }
    if let sym = c {
        glob["cursor"] = [sym: 1]
    }
    guard let cursor = glob["cursor"] as? [String: Any] else { return }

    if (cursor["text"] as? Int) == 1 {
        // cursor(0) — system default cursor
    } else if (cursor["grab_up"] as? Int) == 1 {
        // cursor([member("grab_up cursor").memberNum, member("grab cursor mask").memberNum])
    } else if (cursor["grab_down"] as? Int) == 1 {
        // cursor([member("grab_down cursor").memberNum, member("grab cursor mask").memberNum])
    } else if (cursor["grab_both"] as? Int) == 1 {
        // cursor([member("grab_both cursor").memberNum, member("grab cursor mask").memberNum])
    } else if (cursor["grabber"] as? Int) == 1 {
        // cursor([member("grabber cursor").memberNum, member("grabber cursor mask").memberNum])
    } else if (cursor["eraser"] as? Int) == 1 {
        // cursor([member("eraser cursor").memberNum, member("eraser cursor mask").memberNum])
    } else {
        // cursor(0) — system default cursor
    }
}

func enterFrame() {
    print("My name is Junkbot")
}

func exitFrame() {
    print("I love to eat trash")
}

func prepareFrame() {
    print("Junk is food!")
}

func showGlobals() {
    print("version = \"8.0\"")
}
