#!/bin/sh
# Transcodes every .ogg/.wav file under a source audio directory to Core Audio Format (.caf),
# preserving subdirectory structure (audio/sound-effects/undercover/laser_hit.wav ->
# <output>/sound-effects/undercover/laser_hit.caf, etc.).
#
# Why: almost every asset under audio/ is Ogg Vorbis, a format AVFoundation/AVAudioPlayer can't
# decode - but macOS's built-in `afconvert` tool CAN decode .ogg when run unsandboxed (confirmed
# empirically; Ogg Vorbis is not an Apple-documented supported afconvert input format, but the
# codec component is present on this OS).
#
# `Junkbot.xcodeproj`'s Run Script build phases (macOS/tvOS targets) invoke this script directly
# at build time - Xcode Run Script phases aren't sandboxed, so this works there. iOS is different:
# `JunkbotPlayground.swiftpm` used to invoke this same script via a `TranscodeAudioPlugin`
# SwiftPM build-tool plugin, but SwiftPM always runs plugins sandboxed with no opt-out, and
# `afconvert` fails to decode Ogg Vorbis from inside that sandbox (the exact same command that
# works fine here fails with "Couldn't open input file" when invoked from a plugin's subprocess -
# confirmed, not theoretical). So for iOS this script is instead run manually, once, whenever
# `audio/` changes, with its output checked into
# `JunkbotPlayground.swiftpm/Sources/JunkbotPlayground/TranscodedAudio/` directly (see that
# package's `Package.swift` for the exact invocation) - the one asset directory for that target
# that isn't a symlinked, always-fresh passthrough to the repo-root `audio/` single source of
# truth, unlike images/font/levels.
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
