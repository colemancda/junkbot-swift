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
# Milestone 1 (current): compiles only source/*.swift (no JunkbotCore yet) to
# validate the ported build plumbing in isolation. JunkbotCore integration
# (with the same CORE_EXCLUDE/GENERATED_EXCLUDE convention ports/N64 uses)
# lands once the renderer/game-loop milestones start (see the plan doc).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TOOLCHAIN="${TOOLCHAIN:-/Volumes/Crucial-2TB/Developer/build/Ninja-ReleaseAssert}"
SWIFTC="${SWIFTC:-$TOOLCHAIN/swift-macosx-arm64/bin/swiftc}"

BUILD_DIR="${BUILD_DIR:-build}"
mkdir -p "$BUILD_DIR"

COMMON=common
SWIFT_TARGET=mipsel-none-none-elf

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

echo "Compiling Swift code with host compiler..."
echo "Swift compiler: $SWIFTC"
echo "Target: $SWIFT_TARGET"

"$SWIFTC" \
  "${SWIFTFLAGS_COMMON[@]}" \
  -import-objc-header "$COMMON/psx_umbrella.h" \
  -module-name Junkbot \
  -c "${port_swift[@]}" \
  -o "$BUILD_DIR/swiftlib.o"

if [ ! -f "$BUILD_DIR/swiftlib.o" ]; then
  echo "✗ Swift compilation failed"
  exit 1
fi

echo "✓ Swift compilation successful: $BUILD_DIR/swiftlib.o"
