#!/bin/sh
# Transcodes every .ogg/.wav file under a source audio directory to Core Audio Format (.caf),
# preserving subdirectory structure (audio/sound-effects/undercover/laser_hit.wav ->
# <output>/sound-effects/undercover/laser_hit.caf, etc.).
#
# Why: almost every asset under audio/ is Ogg Vorbis, a format AVFoundation/AVAudioPlayer can't
# decode - but macOS's built-in `afconvert` tool CAN decode .ogg (confirmed empirically; Ogg
# Vorbis is not an Apple-documented supported afconvert input format, but the codec component is
# present on this OS). Transcoding once at build time (rather than shipping a third-party Ogg
# decoder, or checking in duplicate pre-converted assets) keeps the checked-in .ogg/.wav files
# under audio/ as the single source of truth, matching the project's existing principle for
# images/font/levels.
#
# Shared between `Junkbot.xcodeproj`'s Run Script build phases (macOS/tvOS targets) and
# `JunkbotPlayground.swiftpm`'s TranscodeAudioPlugin (iOS) - both just invoke this script with
# different source/output directories, so the actual transcoding logic lives in exactly one
# place.
#
# Usage: transcode-audio.sh <source-audio-dir> <output-dir>
# Skips re-converting a file whose .caf output is already newer than its source, so incremental
# builds stay fast. Continues past a single file's conversion failure (logging to stderr) rather
# than failing the whole build, matching this project's existing tolerant-of-missing-assets
# posture (see e.g. SoundBoard's "Loaded X/Y sound effects" warning in ports/SDL3's main.swift).

set -u

SOURCE_DIR="$1"
OUTPUT_DIR="$2"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "transcode-audio.sh: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

find "$SOURCE_DIR" \( -name '*.ogg' -o -name '*.wav' \) -print | while IFS= read -r src; do
  relative="${src#"$SOURCE_DIR"/}"
  base="${relative%.*}"
  dst="$OUTPUT_DIR/$base.caf"
  mkdir -p "$(dirname "$dst")"

  if [ -f "$dst" ] && [ "$dst" -nt "$src" ]; then
    continue
  fi

  if ! afconvert -f caff -d LEI16@44100 "$src" "$dst" 2>/tmp/transcode-audio-error.$$; then
    echo "transcode-audio.sh: failed to convert $src:" >&2
    cat /tmp/transcode-audio-error.$$ >&2
  fi
  rm -f /tmp/transcode-audio-error.$$
done

exit 0
