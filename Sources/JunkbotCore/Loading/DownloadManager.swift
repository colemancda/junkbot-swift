// Translated from Lingo: parent_download manager.ls

class DownloadManager {
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

    init() {
        files = [moviePath + movieName]
        state = "preload"
        displaysprites = [
            "intro_anim": [sprite(15), sprite(11), sprite(14), sprite(16)],
            "intro_level": [sprite(10), sprite(12), sprite(13)],
            "intro_level_note": [sprite(12), sprite(13)],
            "loaded_arrows": [sprite(3), sprite(4), sprite(5), sprite(6)],
            "loading_msg": [sprite(7)],
            "go_btn": [sprite(8), sprite(17)]
        ]
        displaysaveloc = [:]
        loadp = false
        member("download_msg")?.text = "DOWNLOAD IN PROGRESS"
        db("new")
    }

    func db(_ t: String) {
        // debug stub — no-op
    }

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
            let entry = PropList()
            entry["sprite"] = .object(spr)
            entry["locV"] = .int(origLocV)
            loadingbricksprites.append(entry)
            spr.locV = (origLocV % brickdropspeed) - brickdropspeed - 20
            spr.visible = true
        }
        state = "intro_anim"
        blinktimer = currentTicks
    }

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

    func animDone() {
        state = "sample_level"
        show(["intro_anim"], v: false)
        show(["intro_level"], v: true)
        let currentLevel = member("loading_level")?.text ?? ""
        glob.PLAYER.play_manager.setLevel(currentLevel)
        glob.PLAYER.play_manager.startLevel()
    }

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
                glob.PLAYER.play_manager.setLevel(currentLevel)
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

    func streamStatus(_ URL: String, state: String, bytesSoFar: Int, bytesTotal: Int, error: String) {
        db("streamstatus \(bytesSoFar) \(bytesTotal) \(error)")
        if bytesTotal == 0 { return }
        readybrick = bytesSoFar * 14 / bytesTotal
    }

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
            } else if nextbrick > loadingbricksprites.count && glob.database_manager.READY() {
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
