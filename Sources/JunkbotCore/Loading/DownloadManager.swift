// Translated from Lingo: parent_download manager.ls

class DownloadManager: LingoObject, @unchecked Sendable {
  var files: [String] = []
  var state: String = "preload"
  var displaysprites: [String: [LingoSprite]] = [:]
  var displaysaveloc: [ObjectIdentifier: Point] = [:]
  var loadingbricksprites: [PropList] = []
  var nextbrick: Int = 1
  var readybrick: Int = 0
  var brickdropspeed: Int = 60
  var blinktimer: Int = 0
  var bumpertimer: Int = 0
  var loadp: Bool = false

  // Original Lingo body: new
  // ```lingo
  // on new me
  //   files = [the moviePath && the movieName]
  //   state = #preload
  //   displaysprites = [#intro_anim: [sprite(15), sprite(11), sprite(14), sprite(16)], #intro_level: [sprite(10), sprite(12), sprite(13)], #intro_level_note: [sprite(12), sprite(13)], #loaded_arrows: [sprite(3), sprite(4), sprite(5), sprite(6)], #loading_msg: [sprite(7)], #go_btn: [sprite(8), sprite(17)]]
  //   displaysaveloc = [:]
  //   loadp = 0
  //   member("download_msg").text = "DOWNLOAD IN PROGRESS"
  //   me.db("new")
  //   return me
  // end
  // ```
  override init() {
    super.init()
    files = [moviePath + movieName]
    state = "preload"
    displaysprites = [
      "intro_anim": [sprite(15), sprite(11), sprite(14), sprite(16)],
      "intro_level": [sprite(10), sprite(12), sprite(13)],
      "intro_level_note": [sprite(12), sprite(13)],
      "loaded_arrows": [sprite(3), sprite(4), sprite(5), sprite(6)],
      "loading_msg": [sprite(7)],
      "go_btn": [sprite(8), sprite(17)],
    ]
    displaysaveloc = [:]
    loadp = false
    member("download_msg")?.text = "DOWNLOAD IN PROGRESS"
    db("new")
  }

  // Original Lingo body: db
  // ```lingo
  // on db me, t
  // end
  // ```
  func db(_ t: String) {
      }

  // Original Lingo body: begin
  // ```lingo
  // on begin me
  //   bumpertimer = the ticks
  //   (the actorList).add(me)
  //   me.db("begin")
  //   nextbrick = 1
  //   readybrick = 0
  //   if the runMode contains "Plugin" then
  //     if frameReady() then
  //       me.streamStatus(EMPTY, "Complete", 1000, 1000, "OK")
  //       me.db("plugin frameready")
  //     else
  //       me.db("plugin not frameready")
  //       tellStreamStatus(1)
  //     end if
  //   else
  //     me.db("not plugin")
  //     me.streamStatus(EMPTY, "Complete", 1000, 1000, "OK")
  //   end if
  // end
  // ```
  func begin() {
    bumpertimer = currentTicks
    actorList.append(self)
    db("begin")
    nextbrick = 1
    readybrick = 0
    if runMode.contains("Plugin") {
      if frameReady() {
        streamStatus("", state: "Complete", bytesSoFar: 1000, bytesTotal: 1000, error: "OK")
        db("plugin frameready")
      } else {
        db("plugin not frameready")
        tellStreamStatus(1)
      }
    } else {
      db("not plugin")
      streamStatus("", state: "Complete", bytesSoFar: 1000, bytesTotal: 1000, error: "OK")
    }
  }

  // Original Lingo body: loadingframe
  // ```lingo
  // on loadingframe me
  //   go("loading")
  //   me.db("loadingframe")
  //   SndMusicStart("intro")
  //   displaysaveloc = [:]
  //   displaysaveloc.addProp(sprite(15), sprite(15).loc)
  //   me.show([#intro_anim], 1)
  //   me.show([#intro_level], 0)
  //   brickdropspeed = 60
  //   loadingbricksprites = []
  //   repeat with i = 21 to 34
  //     loadingbricksprites.add([#sprite: sprite(i), #locV: sprite(i).locV])
  //     sprite(i).locV = (sprite(i).locV mod brickdropspeed) - brickdropspeed - 20
  //     sprite(i).visible = 1
  //   end repeat
  //   state = #intro_anim
  //   blinktimer = the ticks
  // end
  // ```
  func loadingframe() {
    go("loading")
    db("loadingframe")
    SndMusicStart("intro")
    displaysaveloc = [:]
    if let s15 = displaysprites["intro_anim"]?.first {
      displaysaveloc[ObjectIdentifier(s15)] = s15.loc ?? Point(x: 0, y: 0)
    }
    show(["intro_anim"], v: true)
    show(["intro_level"], v: false)
    brickdropspeed = 60
    loadingbricksprites = []
    for i in 21...34 {
      let spr = sprite(i)
      let origLocV = spr.locV
      var entry = PropList()
      entry["sprite"] = .object(spr)
      entry["locV"] = .int(origLocV)
      loadingbricksprites.append(entry)
      spr.locV = (origLocV % brickdropspeed) - brickdropspeed - 20
      spr.visible = true
    }
    state = "intro_anim"
    blinktimer = currentTicks
  }

  // Original Lingo body: mainmenu
  // ```lingo
  // on mainmenu me
  //   go("mainmenu")
  //   SndMusicStart("intro")
  //   me.show([#intro_level], 1)
  //   me.show([#intro_level_note, #intro_anim], 0)
  //   me.animDone()
  //   me.show([#go_btn], 1)
  //   repeat with lbs in loadingbricksprites
  //     lbs.sprite.visible = 1
  //   end repeat
  // end
  // ```
  func mainmenu() {
    go("mainmenu")
    SndMusicStart("intro")
    show(["intro_level"], v: true)
    show(["intro_level_note", "intro_anim"], v: false)
    animDone()
    show(["go_btn"], v: true)
    for lbs in loadingbricksprites {
      lbs["sprite"].asObject()?.asSprite?.visible = true
    }
  }

  // Original Lingo body: finish
  // ```lingo
  // on finish me, nextframe
  //   state = #done
  //   tellStreamStatus(0)
  //   (the actorList).deleteOne(me)
  //   repeat with sl in displaysprites
  //     repeat with s in sl
  //       s.visible = 1
  //       sloc = displaysaveloc.getaProp(s)
  //       if not voidp(sloc) then
  //         s.loc = sloc
  //       end if
  //     end repeat
  //   end repeat
  //   repeat with i = 1 to 50
  //     sprite(i).locZ = i
  //   end repeat
  //   go(nextframe)
  // end
  // ```
  func finish(_ nextframe: String) {
    state = "done"
    tellStreamStatus(0)
    actorList.removeAll { $0 === self }
    for (_, sprites) in displaysprites {
      for s in sprites {
        s.visible = true
        if let sloc = displaysaveloc[ObjectIdentifier(s)] {
          s.loc = sloc
        }
      }
    }
    for i in 1...50 {
      sprite(i).locZ = i
    }
    go(nextframe)
  }

  // Original Lingo body: show
  // ```lingo
  // on show me, which, v
  //   repeat with dsn in which
  //     repeat with s in displaysprites[dsn]
  //       s.visible = v
  //       sloc = displaysaveloc.getaProp(s)
  //       if not voidp(sloc) then
  //         if v then
  //           s.loc = sloc
  //           next repeat
  //         end if
  //         s.loc = point(1000, 1000)
  //       end if
  //     end repeat
  //   end repeat
  // end
  // ```
  func show(_ which: [String], v: Bool) {
    for dsn in which {
      guard let sprites = displaysprites[dsn] else { continue }
      for s in sprites {
        s.visible = v
        if let sloc = displaysaveloc[ObjectIdentifier(s)] {
          if v {
            s.loc = sloc
          } else {
            s.loc = Point(x: 1000, y: 1000)
          }
        }
      }
    }
  }

  // Original Lingo body: animdone
  // ```lingo
  // on animDone me
  //   state = #sample_level
  //   me.show([#intro_anim], 0)
  //   me.show([#intro_level], 1)
  //   currentLevel = member("loading_level").text
  //   glob.PLAYER.play_manager.setLevel(currentLevel)
  //   glob.PLAYER.play_manager.startLevel()
  // end
  // ```
  func animDone() {
    state = "sample_level"
    show(["intro_anim"], v: false)
    show(["intro_level"], v: true)
    let currentLevel = member("loading_level")?.text ?? ""
    glob.PLAYER.play_manager.setLevel(.string(currentLevel))
    glob.PLAYER.play_manager.startLevel()
  }

  // Original Lingo body: gbutton
  // ```lingo
  // on gbutton me, which
  //   case which of
  //     #Ok:
  //       if state = #sample_level then
  //         glob.PLAYER.play_manager.leave()
  //       end if
  //       me.finish("levels")
  //     #credits:
  //       if state = #sample_level then
  //         glob.PLAYER.play_manager.leave()
  //       end if
  //       me.finish("credits")
  //     #replay:
  //       if state = #sample_level then
  //         glob.PLAYER.play_manager.leave()
  //         me.show([#intro_anim], 1)
  //         me.show([#intro_level], 0)
  //         state = #intro_msg
  //       end if
  //       displaysprites[#intro_anim][1].gotoFrame(1)
  //       displaysprites[#intro_anim][1].play()
  //     #cleanup:
  //       if state = #sample_level then
  //         currentLevel = member("loading_level").text
  //         glob.PLAYER.play_manager.leave()
  //         glob.PLAYER.play_manager.setLevel(currentLevel)
  //         glob.PLAYER.play_manager.startLevel()
  //       end if
  //     #skip_movie:
  //       if state <> #sample_level then
  //         me.animDone()
  //       end if
  //   end case
  // end
  // ```
  func gbutton(_ which: String) {
    switch which {
    case "Ok":
      if state == "sample_level" {
        glob.PLAYER.play_manager.leave()
      }
      finish("levels")
    case "credits":
      if state == "sample_level" {
        glob.PLAYER.play_manager.leave()
      }
      finish("credits")
    case "replay":
      if state == "sample_level" {
        glob.PLAYER.play_manager.leave()
        show(["intro_anim"], v: true)
        show(["intro_level"], v: false)
        state = "intro_msg"
      }
      displaysprites["intro_anim"]?[0].gotoFrame(1)
      displaysprites["intro_anim"]?[0].play()
    case "cleanup":
      if state == "sample_level" {
        let currentLevel = member("loading_level")?.text ?? ""
        glob.PLAYER.play_manager.leave()
        glob.PLAYER.play_manager.setLevel(.string(currentLevel))
        glob.PLAYER.play_manager.startLevel()
      }
    case "skip_movie":
      if state != "sample_level" {
        animDone()
      }
    default:
      break
    }
  }

  // Original Lingo body: streamstatus
  // ```lingo
  // on streamStatus me, URL, state, bytesSoFar, bytesTotal, error
  //   me.db("streamstatus" && bytesSoFar && bytesTotal && error)
  //   if bytesTotal = 0 then
  //     return
  //   end if
  //   readybrick = bytesSoFar * 14 / bytesTotal
  // end
  // ```
  func streamStatus(_ URL: String, state: String, bytesSoFar: Int, bytesTotal: Int, error: String) {
    db("streamstatus \(bytesSoFar) \(bytesTotal) \(error)")
    if bytesTotal == 0 { return }
    readybrick = bytesSoFar * 14 / bytesTotal
  }

  // Original Lingo body: stepframe
  // ```lingo
  // on stepFrame me
  //   me.db("stepframe nextbrick" && nextbrick && "readybrick" && readybrick)
  //   if state = #preload then
  //     if frameReady(1, marker("loading")) and (the ticks > (bumpertimer + 110)) then
  //       me.loadingframe()
  //     end if
  //   else
  //     if loadp then
  //     else
  //       if (nextbrick > loadingbricksprites.count) and glob.database_manager.READY() then
  //         me.show([#go_btn], 1)
  //         displaysprites.loading_msg[1].member.text = "READY TO PLAY"
  //         blinktimer = the ticks
  //         loadp = 1
  //         movieloaded()
  //       else
  //         if readybrick >= nextbrick then
  //           nb = loadingbricksprites[nextbrick]
  //           if nb.sprite.locV = nb.locV then
  //             nextbrick = nextbrick + 1
  //           else
  //             nb.sprite.locV = nb.sprite.locV + brickdropspeed
  //             if nb.sprite.locV > nb.locV then
  //               nb.sprite.locV = nb.locV
  //             end if
  //           end if
  //         end if
  //       end if
  //     end if
  //   end if
  // end
  // ```
  func stepFrame() {
    db("stepframe nextbrick \(nextbrick) readybrick \(readybrick)")
    if state == "preload" {
      let ticks = currentTicks
      if frameReady(1, marker: "loading") && (ticks > (bumpertimer + 110)) {
        loadingframe()
      }
    } else {
      if loadp {
        // nothing
      } else if nextbrick > loadingbricksprites.count
        && glob.database_manager.READY().asInt ?? 0 != 0
      {
        show(["go_btn"], v: true)
        displaysprites["loading_msg"]?[0].member?.text = "READY TO PLAY"
        blinktimer = currentTicks
        loadp = true
        movieloaded()
      } else if readybrick >= nextbrick {
        let nb = loadingbricksprites[nextbrick - 1]
        let spr = nb["sprite"].asObject()?.asSprite
        let targetLocV = nb["locV"].asInt ?? 0
        if spr?.locV == targetLocV {
          nextbrick += 1
        } else {
          var newLocV = (spr?.locV ?? 0) + brickdropspeed
          if newLocV > targetLocV { newLocV = targetLocV }
          spr?.locV = newLocV
        }
      }
    }
  }
}
