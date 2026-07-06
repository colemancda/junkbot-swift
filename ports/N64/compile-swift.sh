#!/bin/bash

# Compile the Swift sources to a MIPS object on the host: emit LLVM IR with
# Embedded Swift, then lower with llc using a non-abicalls big-endian MIPS
# configuration the N64 linker accepts, then retag the ELF ABI O32 -> O64.
#
# Adapted from MillerTechnologyPeru/swift-embedded-nintendo-64's libdragon
# example (compile-swift.sh) -- see that repo's README for the full
# explanation of the O32/O64 and movn/movz gotchas these flags work around.
#
# Unlike that example (which only imports one bridging header), this port's
# Swift side imports the CN64 module (module.modulemap + common/n64_umbrella.h)
# so the whole-module compile matches ports/3DS/ports/NDS's convention.
#
# SWIFTC must point at `swift-frontend`, invoked directly with `-frontend`,
# not the `swiftc`/`swift-driver` wrapper: the driver binary depends on a
# handful of dylibs (libSwiftDriver.dylib etc.) that live in a *separate*
# bootstrap build tree outside a normal toolchain install, which makes it
# unportable -- swift-frontend alone (plus lib/swift/{shims,clang,embedded}
# and lib/swift/host/compiler's dylibs) is fully self-contained and is
# exactly what's packaged in the CI-downloaded swift-embedded-mac.tar.gz
# (see .github/workflows/swift.yml's n64 job).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SWIFTC="${SWIFTC:?set SWIFTC=/path/to/mips-enabled/swift-frontend}"
LLC="${LLC:?set LLC=/path/to/llc}"

BUILD_DIR="${BUILD_DIR:-build}"
mkdir -p "$BUILD_DIR"

REPO_ROOT=../..
COMMON=common
# Font.swift is SDL-only bitmap-text layout (this port's HUD uses its own
# ASCII-byte table instead, see source/TextRenderer.swift); LevelCatalog.swift
# is Foundation-only text-catalog scanning unreachable from Embedded Swift.
# Same CORE_EXCLUDE as ports/3DS/ports/NDS, and for the same reason (real ROM
# budget: their Unicode/case-mapping data tables cost ~800KB neither of those
# ports' -- nor this one's -- 4MB RDRAM budget can spare).
#
# UndercoverLevelData.swift/LevelData.swift are excluded for the same reason:
# this v1 port only ships the base Junkbot campaign (source/main.swift
# references `junkbotCampaignLevels` from JunkbotLevelData.swift directly),
# and once anything references a generated level array, the *whole* array
# (every entry's entity-builder closure, used or not) becomes reachable --
# there's no way to keep just the referenced elements. Matches ports/NDS's
# GENERATED_EXCLUDE exactly (see its Makefile's comment).
CORE_EXCLUDE=(Font.swift LevelCatalog.swift)
GENERATED_EXCLUDE=(UndercoverLevelData.swift LevelData.swift)

core_swift=()
for f in "$REPO_ROOT"/Sources/JunkbotCore/*.swift; do
  base="$(basename "$f")"
  skip=0
  for ex in "${CORE_EXCLUDE[@]}"; do
    [ "$base" = "$ex" ] && skip=1
  done
  [ "$skip" = 0 ] && core_swift+=("$f")
done
for f in "$REPO_ROOT"/Sources/JunkbotCore/Generated/*.swift; do
  base="$(basename "$f")"
  skip=0
  for ex in "${GENERATED_EXCLUDE[@]}"; do
    [ "$base" = "$ex" ] && skip=1
  done
  [ "$skip" = 0 ] && core_swift+=("$f")
done

port_swift=(source/*.swift)
gen_swift=(
  "$BUILD_DIR/SpriteAssets.swift" "$BUILD_DIR/AudioAssets.swift" "$BUILD_DIR/MusicAssets.swift"
  "$BUILD_DIR/FontAssets.swift"
)

echo "Compiling Swift code with host compiler..."
echo "Swift compiler: $SWIFTC"
echo "LLC:            $LLC"
echo "Target: mips-none-none-elf"

echo "Step 1: Emitting LLVM IR..."
"$SWIFTC" -frontend \
  -target mips-none-none-elf \
  -enable-experimental-feature Embedded \
  -wmo -O \
  -module-name Junkbot \
  -Xcc -fmodule-map-file="$COMMON/module.modulemap" \
  -I "$COMMON" \
  -emit-ir \
  -o "$BUILD_DIR/swiftlib.ll" \
  "${core_swift[@]}" "${port_swift[@]}" "${gen_swift[@]}"

if [ ! -f "$BUILD_DIR/swiftlib.ll" ]; then
  echo "✗ Failed to emit LLVM IR"
  exit 1
fi

# -mips4_32/-mips4_32r2 disable the MIPS IV movn/movz conditional-move
# instructions LLVM would otherwise emit for integer if/ternary/min/max --
# the VR4300 (MIPS III) doesn't have them (Reserved Instruction exception).
echo "Step 2: Compiling IR to object file with llc (non-abicalls, no movn/movz)..."
"$LLC" \
  -mtriple=mips-none-none-elf \
  -mcpu=mips32r2 \
  -mattr=+mips3,+noabicalls,+gp64,+fpxx,+nooddspreg,-mips4_32,-mips4_32r2 \
  -relocation-model=static \
  -filetype=obj \
  -o "$BUILD_DIR/swiftlib.o" \
  "$BUILD_DIR/swiftlib.ll"

if [ ! -f "$BUILD_DIR/swiftlib.o" ]; then
  echo "✗ Swift compilation failed"
  exit 1
fi

# libdragon is built with -mabi=o64, but LLVM cannot emit the O64 ABI (only
# o32/n32/n64), so the linker rejects an O32 Swift object. The object is
# already compiled with +gp64 (64-bit registers), which is exactly what O64
# is -- o32 calling convention with 64-bit registers -- so the code itself is
# compatible; only the ELF e_flags disagree. Patch e_flags from 0x20001101
# (mips3, o32, 32bitmode, noreorder) to 0x20002001 (mips3, o64, noreorder).
echo "Step 3: Retagging ELF ABI O32 -> O64..."
python3 - "$BUILD_DIR/swiftlib.o" <<'PY'
import sys, struct
path = sys.argv[1]
with open(path, "r+b") as f:
    data = bytearray(f.read())
    assert data[:4] == b"\x7fELF", "not an ELF file"
    assert data[5] == 2, "expected big-endian (EI_DATA=2)"   # N64 is MSB
    off = 0x24
    flags = struct.unpack(">I", data[off:off+4])[0]
    new = (flags & ~0x00001100) | 0x00002000  # clear O32(0x1000)+32bitmode(0x100), set O64(0x2000)
    data[off:off+4] = struct.pack(">I", new)
    f.seek(0); f.write(data)
    print(f"  e_flags 0x{flags:08x} -> 0x{new:08x}")
PY

echo "✓ Swift compilation successful: $BUILD_DIR/swiftlib.o"
