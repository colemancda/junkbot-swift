#!/usr/bin/env python3
"""Build-time audio converter for the Nintendo DS port.

`GameEngine.onPlaySound` fires with a `SoundID.rawValue` (Sources/JunkbotCore/
Types.swift, 0...27); this script mirrors ports/SDL2's SoundBoard.paths table
(same IDs -> audio/sound-effects/-relative filenames) and converts each clip
to what the DS's hardware mixer can play directly with no runtime
decoder: signed 8-bit PCM, mono, at the source's native sample rate
(`soundPlaySample(_:format:.Pcm8,...)`, libnds/calico's direct one-shot
sample-playback call - no maxmod/soundbank involved).

The repo's clips are Ogg Vorbis (plus a couple of WAV files); decoding Vorbis
needs a real decoder, which this script doesn't implement in pure Python, so
it shells out to macOS's built-in `afconvert` to get from Ogg to 16-bit PCM
WAV, then downsamples that to 8-bit and (for the one stereo source) downmixes
to mono using only the stdlib `wave` module. WAV sources skip afconvert
entirely. This step is therefore macOS-only, matching this port's other
toolchain assumptions (Xcode toolchains, Homebrew SDL, etc.).

Emits:
  <out>/audio.bin        -- every clip's PCM8 samples, concatenated in
                             SoundID order.
  <out>/AudioAssets.swift -- per-SoundID (offset, length, sampleRate) table.

Usage: gen_audio.py <repo_root> <out_dir>
"""

import subprocess
import struct
import sys
import tempfile
import wave
from pathlib import Path

# SoundID.rawValue -> audio/sound-effects/-relative path. Mirrors
# ports/SDL2/Sources/JunkbotSDL2/main.swift's SoundBoard.paths exactly (see
# Sources/JunkbotCore/Types.swift's SoundID enum for the 0...27 range this
# indexes).
SOUND_PATHS = {
    0: "turn1.ogg",
    1: "blockpickup.ogg",
    2: "blockdrop.ogg",
    3: "blockclick.ogg",
    4: "fall.ogg",
    5: "headbonk1.ogg",
    6: "eat1.ogg",
    7: "garbage1.ogg",
    8: "switch_click.ogg",
    9: "switch_on.ogg",
    10: "switch_off.ogg",
    11: "fire.ogg",
    12: "electricity1.ogg",
    13: "undercover/laser_hit.wav",
    14: "robottouch4.ogg",
    15: "shieldon2.ogg",
    16: "h_powerup1.ogg",
    17: "h_powerdown3.ogg",
    18: "undercover/teleport.wav",
    19: "voice_ohyeah.ogg",
    20: "voice_ouch.ogg",
    21: "voice_uhoh.ogg",
    22: "jump3.ogg",
    23: "fan.ogg",
    24: "drip1.ogg",
    25: "drip2.ogg",
    26: "drip3.ogg",
    27: "lego-creator/undo-I0512.wav",
}


def decode_to_pcm8_mono(path, tmpdir):
    """Returns (sample_rate, bytes) as signed 8-bit PCM mono."""
    if path.suffix.lower() != ".wav":
        wav_path = tmpdir / (path.stem + ".wav")
        subprocess.run(
            ["afconvert", "-f", "WAVE", "-d", "LEI16", str(path), str(wav_path)],
            check=True, capture_output=True)
    else:
        wav_path = path

    with wave.open(str(wav_path), "rb") as w:
        channels = w.getnchannels()
        width = w.getsampwidth()
        rate = w.getframerate()
        raw = w.readframes(w.getnframes())

    if width == 1:
        # Unsigned 8-bit input (rare in this repo, but handle it): center to signed.
        samples16 = [((b - 128) << 8) for b in raw]
    elif width == 2:
        count = len(raw) // 2
        samples16 = list(struct.unpack(f"<{count}h", raw))
    else:
        raise ValueError(f"{path}: unsupported sample width {width}")

    if channels > 1:
        frames = len(samples16) // channels
        mono = [0] * frames
        for i in range(frames):
            frame_samples = samples16[i * channels : (i + 1) * channels]
            mono[i] = sum(frame_samples) // channels
        samples16 = mono

    pcm8 = bytearray(len(samples16))
    for i, s in enumerate(samples16):
        # Signed 16-bit -> signed 8-bit: arithmetic shift, matching how every
        # other PCM16->PCM8 downconvert works (drop the low byte).
        v = s >> 8
        pcm8[i] = v & 0xFF

    return rate, bytes(pcm8)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: gen_audio.py <repo_root> <out_dir>")
    repo_root = Path(sys.argv[1]).resolve()
    out_dir = Path(sys.argv[2]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    sfx_dir = repo_root / "audio/sound-effects"

    blob = bytearray()
    entries = []  # (offset, length, sampleRate) indexed by SoundID
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        for sound_id in range(max(SOUND_PATHS) + 1):
            filename = SOUND_PATHS.get(sound_id)
            if filename is None:
                entries.append((0, 0, 0))
                continue
            src = sfx_dir / filename
            if not src.exists():
                print(f"warning: missing sound effect {src}", file=sys.stderr)
                entries.append((0, 0, 0))
                continue
            rate, pcm8 = decode_to_pcm8_mono(src, tmpdir)
            entries.append((len(blob), len(pcm8), rate))
            blob += pcm8

    (out_dir / "audio.bin").write_bytes(blob)
    lines = ",\n  ".join(
        f"(offset: {offset}, length: {length}, sampleRate: {rate})"
        for offset, length, rate in entries
    )
    (out_dir / "AudioAssets.swift").write_text(
        "// Generated by ports/NDS/tools/gen_audio.py - do not edit.\n"
        "\n"
        "/// Byte offset/length/sample-rate of each `SoundID.rawValue`'s signed\n"
        "/// 8-bit PCM mono clip within `audio.bin`; `length == 0` for an unmapped ID.\n"
        "let audioClipTable: [(offset: Int32, length: Int32, sampleRate: Int32)] = [\n"
        f"  {lines},\n"
        "]\n"
    )
    print(f"audio.bin: {len(entries)} clips, {len(blob)} bytes ({len(blob) / 1024:.1f} KB)")


if __name__ == "__main__":
    main()
