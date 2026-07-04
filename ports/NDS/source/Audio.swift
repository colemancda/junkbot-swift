import CNDS

/// Sound-effect playback for `GameEngine.onPlaySound`, mirroring `ports/SDL2`'s `SoundBoard` but
/// against the DS's own hardware mixer instead of SDL2_mixer: every clip is pre-converted to
/// signed 8-bit PCM at build time (`tools/gen_audio.py`, embedded as `audio.bin`/
/// `build/AudioAssets.swift`) and handed straight to libnds/calico's `soundPlaySample`, which
/// plays it as a one-shot on whichever hardware channel it allocates - no maxmod/soundbank
/// involved, matching this v1 port's "no music, sound effects only" scope.
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
