// Translated from Lingo: movie_main.ls

let version: String = ""

// Original Lingo body: preparemovie
// ```lingo
// on prepareMovie
//   the actorList = []
//   set the exitLock to 1
//   the itemDelimiter = ","
//   glob = [#EDITOR: [:], #catalog: [:], #PLAYER: [:]]
//   glob[#config_manager] = new(script("config manager"))
//   glob[#download_manager] = new(script("download manager"))
//   glob[#legoparts_manager] = new(script("legoparts manager"))
//   glob.PLAYER[#play_manager] = new(script("play manager"))
//   glob[#database_manager] = new(script("database manager"))
//   initSound()
//   glob[#authorMode] = 0
//   glob[#split_tall_members] = 1
//   put "0" into field "editor par field"
//   put EMPTY into field "catalog title"
//   put EMPTY into field "editor hint field"
// end
// ```
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

// Original Lingo body: startmovie
// ```lingo
// on startMovie
//   glob[#rankdata] = [:]
//   glob[#rankdata][#keys] = 0
//   glob[#rankdata][#moves] = 0
//   glob[#rankdata][#rank] = 0
//   glob[#rankdata][#players] = 0
//   glob.download_manager.begin()
//   glob.database_manager.getState()
// end
// ```
func startMovie() {
    var rankdata = PropList()
    rankdata["keys"] = .int(0)
    rankdata["moves"] = .int(0)
    rankdata["rank"] = .int(0)
    rankdata["players"] = .int(0)
    Glob.shared["rankdata"] = .propList(rankdata)
    // glob.download_manager.begin()
    // glob.database_manager.getState()
}

// Original Lingo body: movieloaded
// ```lingo
// on movieloaded
//   glob.PLAYER[#game_manager] = new(script("game manager"))
//   glob.EDITOR[#edit_manager] = new(script("edit manager"))
//   glob.catalog[#catalog_manager] = new(script("catalog manager"))
// end
// ```
func movieloaded() {
    // glob.PLAYER["game_manager"] = new(script("game manager"))
    // glob.EDITOR["edit_manager"] = new(script("edit manager"))
    // glob.catalog["catalog_manager"] = new(script("catalog manager"))
}

// Original Lingo body: stopmovie
// ```lingo
// on stopMovie
//   the actorList = []
// end
// ```
func stopMovie() {
    // the actorList = []
}

// Original Lingo body: streamstatus
// ```lingo
// on streamStatus URL, state, bytesSoFar, bytesTotal, error
//   glob.download_manager.streamStatus(URL, state, bytesSoFar, bytesTotal)
// end
// ```
func streamStatus(url: String, bytesSoFar: Int, bytesTotal: Int) {
    // glob.download_manager.streamStatus(url, state, bytesSoFar, bytesTotal)
}

// Original Lingo body: keydown
// ```lingo
// on keyDown me
//   sendAllSprites(#equiv_keydown, the key)
// end
// ```
func keyDown(key: String) {
    // sendAllSprites(#equiv_keydown, key)
}

// Original Lingo body: gbutton
// ```lingo
// on gbutton msg
//   case msg of
//     #main_edit:
//       do_editor()
//     #main_play:
//       do_player()
//     #main_catalog:
//       do_catalog()
//   end case
// end
// ```
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

// Original Lingo body: do_editor
// ```lingo
// on do_editor
//   if the frame = marker("play") then
//     glob.PLAYER.play_manager.leave()
//   end if
//   go(marker("edit"))
//   glob.EDITOR.edit_manager.refresh()
// end
// ```
func do_editor() {
    // if the frame == marker("play"): glob.PLAYER.play_manager.leave()
    // go(marker("edit"))
    // glob.EDITOR.edit_manager.refresh()
}

// Original Lingo body: do_catalog
// ```lingo
// on do_catalog
//   if the frame = marker("edit") then
//     glob.EDITOR.edit_manager.leave()
//   end if
//   if the frame = marker("play") then
//     glob.PLAYER.play_manager.leave()
//   end if
//   go(marker("catalog"))
//   glob.catalog.catalog_manager.catalog()
// end
// ```
func do_catalog() {
    // if the frame == marker("edit"): glob.EDITOR.edit_manager.leave()
    // if the frame == marker("play"): glob.PLAYER.play_manager.leave()
    // go(marker("catalog"))
    // glob.catalog.catalog_manager.catalog()
}

// Original Lingo body: do_player
// ```lingo
// on do_player
//   if the frame = marker("edit") then
//     glob.EDITOR.edit_manager.leave()
//   end if
//   glob.PLAYER.game_manager.startGame()
// end
// ```
func do_player() {
    // if the frame == marker("edit"): glob.EDITOR.edit_manager.leave()
    // glob.PLAYER.game_manager.startGame()
}

// Original Lingo body: setcursoreffect
// ```lingo
// on setCursorEffect ce
//   if glob[#cursor] = VOID then
//     glob[#cursor] = [:]
//   end if
//   glob[#cursor][ce] = 1
//   setCursor()
// end
// ```
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

// Original Lingo body: clearcursoreffect
// ```lingo
// on clearCursorEffect ce
//   if glob[#cursor] = VOID then
//     glob[#cursor] = [:]
//   end if
//   if ce = #all then
//     glob[#cursor] = [:]
//   else
//     glob[#cursor][ce] = 0
//   end if
//   setCursor()
// end
// ```
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

// Original Lingo body: setcursor
// ```lingo
// on setCursor c
//   if glob[#cursor] = VOID then
//     glob[#cursor] = [:]
//   end if
//   if ilk(c) = #symbol then
//     glob[#cursor] = [:]
//     glob[#cursor][c] = 1
//   end if
//   if glob[#cursor][#text] then
//     cursor(0)
//   else
//     if glob[#cursor][#grab_up] then
//       cursor([member("grab_up cursor").memberNum, member("grab cursor mask").memberNum])
//     else
//       if glob[#cursor][#grab_down] then
//         cursor([member("grab_down cursor").memberNum, member("grab cursor mask").memberNum])
//       else
//         if glob[#cursor][#grab_both] then
//           cursor([member("grab_both cursor").memberNum, member("grab cursor mask").memberNum])
//         else
//           if glob[#cursor][#grabber] then
//             cursor([member("grabber cursor").memberNum, member("grabber cursor mask").memberNum])
//           else
//             if glob[#cursor][#eraser] = 1 then
//               cursor([member("eraser cursor").memberNum, member("eraser cursor mask").memberNum])
//             else
//               cursor(0)
//             end if
//           end if
//         end if
//       end if
//     end if
//   end if
// end
// ```
func setCursor(_ c: String?) {
    let g = Glob.shared
    if g["cursor"].isVoid {
        g["cursor"] = .propList(PropList())
    }
    if let sym = c {
        var newCursor = PropList()
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

// Original Lingo body: enterframe
// ```lingo
// on enterFrame
//   put "My name is Junkbot"
// end
// ```
func enterFrame() {
    debugLog("My name is Junkbot")
}

// Original Lingo body: exitframe
// ```lingo
// on exitFrame
//   put "I love to eat trash"
// end
// ```
func exitFrame() {
    debugLog("I love to eat trash")
}

// Original Lingo body: prepareframe
// ```lingo
// on prepareFrame
//   put "Junk is food!"
// end
// ```
func prepareFrame() {
    debugLog("Junk is food!")
}

// Original Lingo body: showglobals
// ```lingo
// on showGlobals
//   put "version = " & QUOTE & "8.0"
// end
// ```
func showGlobals() {
    debugLog("version = \"8.0\"")
}
