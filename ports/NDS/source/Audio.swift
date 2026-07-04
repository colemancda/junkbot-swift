import CNDS

/// Sound-effect playback for `GameEngine.onPlaySound`, mirroring `ports/SDL2`'s `SoundBoard` but
/// against the DS's own hardware mixer instead of SDL2_mixer: every clip is pre-converted to
/// signed 8-bit PCM at build time (`tools/gen_audio.py`, embedded as `audio.bin`/
/// `build/AudioAssets.swift`) and handed straight to libnds/calico's `soundPlaySample`, which
/// plays it as a one-shot on whichever hardware channel it allocates - no maxmod/soundbank
/// involved.
let audioBytes: UnsafePointer<UInt8> =
  nds_asset_audio_bin()!.assumingMemoryBound(to: UInt8.self)

func playSound(_ id: Int32) {
  guard id >= 0, Int(id) < audioClipTable.count else { return }
  let clip = audioClipTable[Int(id)]
  guard clip.length > 0 else { return }
  // `SoundFormat_8Bit` is a `#define` alias for `SoundFmt_Pcm8` that Swift's
  // ClangImporter doesn't surface; use the real enum case directly.
  _ = soundPlaySample(
    audioBytes + Int(clip.offset), SoundFmt_Pcm8, UInt32(clip.length),
    UInt16(clip.sampleRate), 127, 64, false, 0)
}

/// Background music, simplified from `ports/SDL2`'s `MusicPlayer` (5 named "level" groups, one
/// picked at random per level): every candidate track is pre-converted at build time
/// (`tools/gen_music.py`, embedded as `music.bin`/`build/MusicAssets.swift`, downsampled to 8kHz
/// to fit the DS's ARM9 image budget alongside sprites/levels/sound effects) and one track from
/// the chosen group is looped forever in hardware (`soundPlaySample(...,loop:true,loopPoint:0)`)
/// - no per-frame CPU work needed once started, unlike a real streaming player, at the cost of
/// this v1 port not shuffling between a group's tracks the way `ports/SDL2` does.
let musicBytes: UnsafePointer<UInt8> =
  nds_asset_music_bin()!.assumingMemoryBound(to: UInt8.self)

/// The currently-playing music channel, or `nil` if none (returned by `soundPlaySample`,
/// consumed by `soundKill`).
var currentMusicChannel: Int32? = nil

/// Stops whatever's playing and starts a random track from a random group - call once per level
/// load, mirroring `SndMusicStart("level" & random(5))`.
func startRandomLevelMusic() {
  stopMusic()
  guard let group = musicGroups.randomElement(), let clip = group.randomElement(),
    clip.length > 0
  else { return }
  currentMusicChannel = soundPlaySample(
    musicBytes + Int(clip.offset), SoundFmt_Pcm8, UInt32(clip.length),
    UInt16(musicGroupSampleRate), 127, 64, true, 0)
}

func stopMusic() {
  if let channel = currentMusicChannel {
    soundKill(channel)
  }
  currentMusicChannel = nil
}
