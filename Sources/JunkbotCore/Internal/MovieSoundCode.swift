// Translated from Lingo: movie_Sound Code.ls

/// Global sound state — stored as a PropList.
let soundState: PropList = PropList()

func initSound() {
    soundState["whichMusic"] = .string("none")
    soundState["musicChannel1"] = .int(1)
    soundState["musicChannel2"] = .int(2)
    let sfxChannels = LingoList()
    sfxChannels.add(.int(3))
    sfxChannels.add(.int(4))
    sfxChannels.add(.int(5))
    sfxChannels.add(.int(6))
    sfxChannels.add(.int(7))
    sfxChannels.add(.int(8))
    soundState["sfxChannels"] = .list(sfxChannels)
    soundState["musicIsPlaying"] = .int(0)
    soundState["soundSection"] = .int(0)
}

func SndCheckPlaylist() {
    // if soundState["musicIsPlaying"].asInt == 1
    //   && sound(musicChannel1).getPlayList().count < 5:
    //     SndLevelQueue()
    // Stub: platform sound API integration needed
}

func SndLevelQueue() {
    guard let playlist1 = soundState["whichMusic"].asString else { return }
    // Build and queue music from the playlist member text.
    // Stub: platform sound API integration needed.
    _ = playlist1
}

func SndMusicStart(_ whichMusic: String) {
    debugLog(whichMusic)
    soundState["whichMusic"] = .string(whichMusic)
    // sound(musicChannel1).stop()
    // Build playlist from member text lines, queue on channel 1, then play.
    // Stub: platform sound API integration needed.
    soundState["musicIsPlaying"] = .int(1)
}

func SndMusicEnd() {
    guard soundState["musicIsPlaying"].asInt == 1 else { return }
    soundState["musicIsPlaying"] = .int(0)
    // sound(musicChannel1).setPlayList([:])
    // sound(musicChannel2).setPlayList([:])
    // If a ".end" playlist member exists, queue and play it.
    // Stub: platform sound API integration needed.
}

/// Count non-empty lines in a music playlist member, minus the header line.
func SNDGetLineCount(_ myMember: String) -> Int {
    // In Director this reads the text of a cast member named myMember.
    // Stub: return 0 until member text is accessible.
    return 0
}

func SndStop() {
    soundState["soundSection"] = .string("0")
    // stop and clear all music and sfx channels
    // Stub: platform sound API integration needed.
    soundState["musicIsPlaying"] = .int(0)
}

/// Play a sound effect on the first available SFX channel.
func SndSFX(_ whichSound: String, sfxpan: Int = 0, sfxlevel: Int = 255, sfxpitch: Int = 0) {
    guard let sfxChannels = soundState["sfxChannels"].asList else { return }
    // Find first idle channel and play, or fall back to channel 1.
    // Stub: platform sound API (e.g. AVAudioPlayer) integration needed.
    _ = sfxChannels
    _ = whichSound
    _ = sfxpan
    _ = sfxlevel
    _ = sfxpitch
}
