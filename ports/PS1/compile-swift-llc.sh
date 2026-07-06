#!/bin/bash
#
# EXPERIMENTAL diagnostic variant of compile-swift.sh, for investigating
# KNOWN_ISSUES.md's Array-allocation-size-corruption bug: routes through
# `swift-frontend -emit-ir` + `llc` (same shape as ports/N64/compile-swift.sh)
# instead of plain `swiftc -c`, using the SAME patched toolchain -- to test
# whether the bug is specific to swiftc's integrated MIPS codegen invocation,
# or lives in the (shared) LLVM MIPS backend itself and reproduces via llc too.
#
# Not part of the normal build -- compile-swift.sh is still the real one.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TOOLCHAIN="${TOOLCHAIN:-/Volumes/Crucial-2TB/Developer/build/Ninja-ReleaseAssert}"
SWIFT_FRONTEND="${SWIFT_FRONTEND:-$TOOLCHAIN/swift-macosx-arm64/bin/swift-frontend}"
LLC="${LLC:-$TOOLCHAIN/llvm-macosx-arm64/bin/llc}"

BUILD_DIR="${BUILD_DIR:-build}"
mkdir -p "$BUILD_DIR"

COMMON=common
SWIFT_TARGET=mipsel-none-none-elf

port_swift=(source/main.swift)

echo "Step 1: Emitting LLVM IR with swift-frontend..."
"$SWIFT_FRONTEND" -frontend \
  -target "$SWIFT_TARGET" \
  -enable-experimental-feature Embedded \
  -wmo -Osize \
  -Xcc -march=mips1 \
  -Xcc -mabi=o32 \
  -Xcc -mno-abicalls \
  -Xcc -fno-pic \
  -Xcc -fno-PIC \
  -Xcc -msoft-float \
  -Xcc -fno-stack-protector \
  -Xcc "-I$SCRIPT_DIR/psn00bsdk/include" \
  -Xcc -w \
  -import-objc-header "$COMMON/psx_umbrella.h" \
  -module-name Junkbot \
  -emit-ir \
  -o "$BUILD_DIR/swiftlib.ll" \
  "${port_swift[@]}"

if [ ! -f "$BUILD_DIR/swiftlib.ll" ]; then
  echo "✗ Failed to emit LLVM IR"
  exit 1
fi

echo "Step 2: Lowering IR to object with llc (mips1, noabicalls, static)..."
"$LLC" \
  -mtriple=mipsel-none-none-elf \
  -mcpu=mips1 \
  -mattr=+noabicalls,+soft-float \
  -relocation-model=static \
  -filetype=obj \
  -o "$BUILD_DIR/swiftlib.o" \
  "$BUILD_DIR/swiftlib.ll"

if [ ! -f "$BUILD_DIR/swiftlib.o" ]; then
  echo "✗ llc lowering failed"
  exit 1
fi

echo "✓ Swift compilation (emit-ir + llc path) successful: $BUILD_DIR/swiftlib.o"
