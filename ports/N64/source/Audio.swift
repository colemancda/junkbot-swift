import CN64

/// Software PCM mixer for `GameEngine.onPlaySound` and background music, playing
/// against libdragon's low-level audio API (`audio_write_begin`/`audio_write_end`,
/// see common/shim.c) instead of a per-channel hardware mixer like the 3DS's NDSP
/// or the DS's `soundPlaySample`. libdragon's API only hands back a raw stereo
/// int16 ring buffer -- there's no per-clip hardware voice to point at a ROM
/// address the way ports/3DS/ports/NDS do -- so this keeps a small number of
/// "voices" (mono PCM8 source + a fixed-point read position/step for rate
/// conversion to the output rate) and mixes them into that buffer by hand every
/// time libdragon has room for more (once or twice per frame at 22050Hz/4 buffers).
///
/// Clips are signed 8-bit PCM mono, same budget-driven format and clip tables as
/// ports/NDS's tools/gen_audio.py/tools/gen_music.py (copied verbatim) -- the
/// N64's whole-ELF 4MB RDRAM budget has no more room for 16-bit/native-rate audio
/// than the DS's ARM9 image does.

private let outputRate: Int32 = 22050
private let maxVoices = 6  // a handful of simultaneous sound effects + 1 music voice

private struct Voice {
  var data: UnsafePointer<Int8>?
  var lengthSamples: Int32 = 0
  /// Q16.16 fixed-point read position, in source samples.
  var posFixed: Int64 = 0
  /// Q16.16 fixed-point step per output sample (sourceRate / outputRate).
  var stepFixed: Int64 = 0
  var looping = false
  var active = false
}

private var voices = [Voice](repeating: Voice(), count: maxVoices)
/// The music voice is always slot `maxVoices - 1`, so a new sound effect never
/// evicts it and stopping music never disturbs sound-effect slots.
private let musicVoiceIndex = maxVoices - 1

let audioBytes: UnsafePointer<Int8> =
  n64_asset_audio_bin()!.assumingMemoryBound(to: Int8.self)
let musicBytes: UnsafePointer<Int8> =
  n64_asset_music_bin()!.assumingMemoryBound(to: Int8.self)

private func start(voiceIndex: Int, base: UnsafePointer<Int8>, offset: Int32, length: Int32, sampleRate: Int32, loop: Bool) {
  guard length > 0 else { return }
  var v = Voice()
  v.data = base + Int(offset)
  v.lengthSamples = length
  v.posFixed = 0
  v.stepFixed = (Int64(sampleRate) << 16) / Int64(outputRate)
  v.looping = loop
  v.active = true
  voices[voiceIndex] = v
}

func playSound(_ id: Int32) {
  guard id >= 0, Int(id) < audioClipTable.count else { return }
  let clip = audioClipTable[Int(id)]
  guard clip.length > 0 else { return }
  // Find a free non-music slot, or steal the oldest sound-effect slot (index 0)
  // if all are busy -- a puzzle game rarely has more than 1-2 clips overlapping.
  var slot = -1
  for i in 0..<musicVoiceIndex where !voices[i].active {
    slot = i
    break
  }
  if slot < 0 { slot = 0 }
  start(voiceIndex: slot, base: audioBytes, offset: clip.offset, length: clip.length, sampleRate: clip.sampleRate, loop: false)
}

func startRandomLevelMusic() {
  stopMusic()
  guard let group = musicGroups.randomElement(), let clip = group.randomElement(),
    clip.length > 0
  else { return }
  start(voiceIndex: musicVoiceIndex, base: musicBytes, offset: clip.offset, length: clip.length, sampleRate: musicGroupSampleRate, loop: true)
}

func stopMusic() {
  voices[musicVoiceIndex].active = false
}

/// Mixes all active voices into every audio buffer libdragon currently has room
/// for (`n64_audio_can_write`), converting each voice's source rate to
/// `outputRate` by nearest-neighbor fixed-point resampling. Call once per frame
/// from the main loop.
func pumpAudio() {
  while n64_audio_can_write() != 0 {
    let sampleCount = Int(n64_audio_buffer_length())
    let address = n64_audio_begin()
    let out = UnsafeMutablePointer<Int16>(bitPattern: UInt(address))!

    var i = 0
    while i < sampleCount {
      var mix: Int32 = 0
      for slot in 0..<maxVoices where voices[slot].active {
        // Signed 8-bit -> signed 16-bit range, matching every other port's
        // PCM8->PCM16 upconvert (replicate into the low byte).
        let sample8 = Int32(voices[slot].data![Int(voices[slot].posFixed >> 16)])
        mix &+= sample8 << 8
        voices[slot].posFixed &+= voices[slot].stepFixed
        if voices[slot].posFixed >> 16 >= Int64(voices[slot].lengthSamples) {
          if voices[slot].looping {
            voices[slot].posFixed &-= Int64(voices[slot].lengthSamples) << 16
          } else {
            voices[slot].active = false
          }
        }
      }
      let clamped = Int16(max(-32768, min(32767, mix)))
      out[i * 2] = clamped  // left
      out[i * 2 + 1] = clamped  // right
      i &+= 1
    }

    n64_audio_end()
  }
}
