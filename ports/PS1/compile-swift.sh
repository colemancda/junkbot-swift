#!/bin/bash
#
# Compile the Swift sources to a mipsel object on the host, using the
# hand-patched Embedded Swift toolchain from ~/Developer/swift-embedded-ps1
# (see that repo's README for the LLVM/clang/lld patches it requires -- plain
# upstream/nightly Swift has no mipsel-none-none-elf + -mno-abicalls support).
#
# Unlike ports/N64/compile-swift.sh (which must emit LLVM IR and lower it
# separately with `llc`, because that target's toolchain is an official
# Embedded-Swift MIPS slice with no native codegen for the VR4300's quirks),
# this toolchain's patches let plain `swiftc -c` emit the object directly --
# same invocation shape as ~/Developer/swift-embedded-ps1/Makefile's
# SWIFTFLAGS_COMMON for its four examples.
#
# JunkbotCore is compiled in alongside source/*.swift, same
# CORE_EXCLUDE/GENERATED_EXCLUDE convention as ports/N64/compile-swift.sh:
# Font.swift/LevelCatalog.swift are Foundation-heavy and unreachable from
# Embedded Swift. UndercoverLevelData.swift/LevelData.swift are excluded
# because this v1 port only ships the base campaign.
#
# JunkbotLevelData.swift is ALSO excluded for now (unlike ports/N64, which
# compiles it): the full base campaign's entity-builder closures compile to
# ~1.1MB of MIPS code, which -- combined with the 0.72MB sprite atlas and the
# renderer's 320x240 RAM framebuffer -- overflows PS1's ~1.98MB usable RAM
# region (confirmed empirically: `.bss overflowed by 158272 bytes` at link
# time). source/main.swift hand-builds one small test level via
# GameEngine.make*() instead, to unblock the rendering pipeline while the
# real fix (either a PS1-specific trimmed level subset, or shrinking the
# sprite atlas) is still open -- see the plan doc's flagged "Level/asset
# budget" risk section.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TOOLCHAIN="${TOOLCHAIN:-/Volumes/Crucial-2TB/Developer/build/Ninja-ReleaseAssert}"
SWIFTC="${SWIFTC:-$TOOLCHAIN/swift-macosx-arm64/bin/swiftc}"

BUILD_DIR="${BUILD_DIR:-build}"
mkdir -p "$BUILD_DIR"

COMMON=common
SWIFT_TARGET=mipsel-none-none-elf
REPO_ROOT=../..

CORE_EXCLUDE=(Font.swift LevelCatalog.swift)
GENERATED_EXCLUDE=(UndercoverLevelData.swift LevelData.swift JunkbotLevelData.swift)

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

SWIFTFLAGS_COMMON=(
  -target "$SWIFT_TARGET"
  -enable-experimental-feature Embedded
  -wmo
  -Osize
  -Xcc -march=mips1
  -Xcc -mabi=o32
  -Xcc -mno-abicalls
  -Xcc -fno-pic
  -Xcc -fno-PIC
  -Xcc -msoft-float
  -Xcc -fno-stack-protector
  -Xcc "-I$SCRIPT_DIR/psn00bsdk/include"
  -Xcc -w
  -Xllvm -mattr=+noabicalls
  -Xllvm -relocation-model=static
)

port_swift=(source/*.swift)
gen_swift=("$BUILD_DIR/SpriteAssets.swift")

echo "Compiling Swift code with host compiler..."
echo "Swift compiler: $SWIFTC"
echo "Target: $SWIFT_TARGET"

"$SWIFTC" \
  "${SWIFTFLAGS_COMMON[@]}" \
  -import-objc-header "$COMMON/psx_umbrella.h" \
  -module-name Junkbot \
  -c "${core_swift[@]}" "${port_swift[@]}" "${gen_swift[@]}" \
  -o "$BUILD_DIR/swiftlib.o"

if [ ! -f "$BUILD_DIR/swiftlib.o" ]; then
  echo "✗ Swift compilation failed"
  exit 1
fi

echo "✓ Swift compilation successful: $BUILD_DIR/swiftlib.o"
