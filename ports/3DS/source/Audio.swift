import CTRU

/// Sound-effect and music playback for `GameEngine.onPlaySound`, mirroring
/// `ports/NDS`'s `Audio.swift` against the 3DS's NDSP (audio DSP) instead of
/// libnds/calico's hardware mixer. Every clip is pre-converted at build time
/// (`tools/gen_audio.py`/`tools/gen_music.py`, embedded as `audio.bin`/`music.bin`)
/// to signed 16-bit PCM mono at its native sample rate -- the 3DS's RAM budget
/// (unlike the DS's) doesn't force an 8-bit/downsampled compromise. `ctru_play_pcm16`
/// (common/shim.c) owns the actual `ndspChnWaveBufAdd` call and the DSP-safe
/// linear-memory copies of both blobs.

/// NDSP channel reserved for music; sound effects round-robin over the rest.
private let musicChannel: Int32 = 0
private let sfxChannelCount: Int32 = 8
private var nextSFXChannel: Int32 = 1

func playSound(_ id: Int32) {
  guard id >= 0, Int(id) < audioClipTable.count else { return }
  let clip = audioClipTable[Int(id)]
  guard clip.length > 0 else { return }
  let channel = nextSFXChannel
  nextSFXChannel = 1 + (nextSFXChannel % sfxChannelCount)
  ctru_play_pcm16(
    channel, /* bank: */ 0, UInt32(clip.offset) / 2, UInt32(clip.length) / 2,
    Float(clip.sampleRate), /* loop: */ 0)
}

/// Background music: one randomly-picked-at-level-load group of loopable clips
/// (mirrors `ports/NDS`'s simplified v1 music, `musicGroups` in generated
/// `MusicAssets.swift`) looped forever in hardware -- no per-frame CPU work
/// needed once started.
func startRandomLevelMusic() {
  stopMusic()
  guard let group = musicGroups.randomElement(), let clip = group.randomElement(),
    clip.length > 0
  else { return }
  ctru_play_pcm16(
    musicChannel, /* bank: */ 1, UInt32(clip.offset) / 2, UInt32(clip.length) / 2,
    Float(clip.sampleRate), /* loop: */ 1)
}

func stopMusic() {
  ctru_stop_channel(musicChannel)
}
