#!/bin/bash

# Build the Junkbot N64 port: libdragon + Embedded Swift, two phases because
# Embedded Swift has no mips-none-none-elf release toolchain (needs a custom
# build) and libdragon's mips64-elf GCC only exists inside this directory's
# Docker image:
#   1. Generate build-time assets (sprites/audio/music/font/levels) on the host.
#   2. Compile Swift to a MIPS object on the host (compile-swift.sh) and
#      retag it O64.
#   3. Build the libdragon Docker image (first run builds libdragon, a few
#      minutes; cached after).
#   4. Compile the C side and link Junkbot.z64 inside the container via `make`
#      (libdragon's n64.mk).
#
# Requires:
#   - SWIFTC: a custom (non-release) Embedded Swift toolchain whose stdlib
#     ships a mips-none-none-elf slice.
#   - LLC: an llc with the MIPS backend (any reasonably recent LLVM/Homebrew
#     llvm build; MIPS ships in mainline LLVM by default).
#   - Docker, for the libdragon mips64-elf GCC toolchain + library.
#   - macOS (tools/gen_audio.py / gen_music.py / gen_font.py shell out to
#     afconvert/sips), matching every other native port's asset pipeline.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REPO_ROOT=../..
BUILD_DIR="${BUILD_DIR:-build}"
mkdir -p "$BUILD_DIR"

DEFAULT_SWIFTC=/Volumes/Crucial-2TB/Developer/build/Ninja-ReleaseAssert/swift-macosx-arm64/bin/swiftc
SWIFTC="${SWIFTC:-$DEFAULT_SWIFTC}"
if [ ! -x "$SWIFTC" ]; then SWIFTC="$(which swiftc)"; fi
export SWIFTC

DEFAULT_LLC=/opt/homebrew/Cellar/llvm/22.1.7_1/bin/llc
LLC="${LLC:-$DEFAULT_LLC}"
if [ ! -x "$LLC" ]; then LLC="$(which llc 2>/dev/null || echo '')"; fi
if [ -z "$LLC" ] || [ ! -x "$LLC" ]; then
  echo "✗ No llc found. Set LLC=/path/to/llc (needs the MIPS backend)."
  exit 1
fi
export LLC

echo "Step 1: Generating build-time assets..."
python3 tools/gen_assets.py "$REPO_ROOT" "$BUILD_DIR"
python3 tools/gen_audio.py "$REPO_ROOT" "$BUILD_DIR"
python3 tools/gen_music.py "$REPO_ROOT" "$BUILD_DIR"
python3 tools/gen_font.py "$REPO_ROOT" "$BUILD_DIR"
swift run -c release --package-path tools/LevelDump LevelDump "$REPO_ROOT" "$BUILD_DIR/LevelAssets.swift"

echo "Step 2: Compiling Swift on host system..."
./compile-swift.sh

if [ ! -f "$BUILD_DIR/swiftlib.o" ]; then
  echo "❌ Swift compilation failed"
  exit 1
fi
echo "✅ Swift compilation successful"

# The runtime archives Junkbot's Embedded Swift object links against
# (libswiftEmbeddedPlatformPOSIX/ExclusivitySingleThreaded/UnicodeDataTables)
# ship alongside SWIFTC's own lib/ tree but the libdragon Makefile expects
# them at swift-libs/mips-none-none-elf/ -- copy them in if missing (this step
# is manual/undocumented in the swift-embedded-nintendo-64 reference this port
# is modeled on).
SWIFT_LIB_SRC="$(dirname "$(dirname "$SWIFTC")")/lib/swift/embedded/mips-none-none-elf"
mkdir -p swift-libs/mips-none-none-elf
for lib in libswiftEmbeddedPlatformPOSIX.a libswiftExclusivitySingleThreaded.a libswiftUnicodeDataTables.a; do
  if [ ! -f "swift-libs/mips-none-none-elf/$lib" ]; then
    if [ ! -f "$SWIFT_LIB_SRC/$lib" ]; then
      echo "✗ Missing $lib -- expected at $SWIFT_LIB_SRC/$lib (does SWIFTC ship an Embedded mips-none-none-elf slice?)"
      exit 1
    fi
    cp "$SWIFT_LIB_SRC/$lib" "swift-libs/mips-none-none-elf/$lib"
  fi
done

echo "Step 3: Building libdragon Docker image (first run builds libdragon, ~several minutes)..."
docker build --platform linux/amd64 -t junkbot-n64 -f Dockerfile .

echo "Step 4: Compiling C and linking ROM in Docker..."
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/workspace" \
  -w /workspace \
  junkbot-n64 \
  make

echo "✅ Build complete!"
if [ -f "Junkbot.z64" ]; then
  echo "🎮 ROM file created: Junkbot.z64"
  ls -lh Junkbot.z64
fi
