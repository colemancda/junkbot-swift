// Translated from Lingo: movie_Sound Code.ls

import Foundation

/// Global sound state — mirrors the glob entries used by the sound system.
var soundState: [String: Any] = [:]

func initSound() {
    soundState["whichMusic"] = "none"
    soundState["musicChannel1"] = 1
    soundState["musicChannel2"] = 2
    soundState["sfxChannels"] = [3, 4, 5, 6, 7, 8]
    soundState["musicIsPlaying"] = 0
    soundState["soundSection"] = 0
}

func SndCheckPlaylist() {
    // if (soundState["musicIsPlaying"] as? Int) == 1
    //   && sound(musicChannel1).getPlayList().count < 5:
    //     SndLevelQueue()
    // Stub: platform sound API integration needed
}

func SndLevelQueue() {
    guard let playlist1 = soundState["whichMusic"] as? String else { return }
    // Build and queue music from the playlist member text.
    // Stub: platform sound API integration needed.
    _ = playlist1
}

func SndMusicStart(_ whichMusic: String) {
    print(whichMusic)
    soundState["whichMusic"] = whichMusic
    // sound(musicChannel1).stop()
    // Build playlist from member text lines, queue on channel 1, then play.
    // Stub: platform sound API integration needed.
    soundState["musicIsPlaying"] = 1
}

func SndMusicEnd() {
    guard (soundState["musicIsPlaying"] as? Int) == 1 else { return }
    soundState["musicIsPlaying"] = 0
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
    soundState["soundSection"] = "0"
    // stop and clear all music and sfx channels
    // Stub: platform sound API integration needed.
    soundState["musicIsPlaying"] = 0
}

/// Play a sound effect on the first available SFX channel.
func SndSFX(_ whichSound: String, sfxpan: Int = 0, sfxlevel: Int = 255, sfxpitch: Int = 0) {
    guard let sfxChannels = soundState["sfxChannels"] as? [Int] else { return }
    // Find first idle channel and play, or fall back to channel 1.
    // Stub: platform sound API (e.g. AVAudioPlayer) integration needed.
    _ = sfxChannels
    _ = whichSound
    _ = sfxpan
    _ = sfxlevel
    _ = sfxpitch
}
