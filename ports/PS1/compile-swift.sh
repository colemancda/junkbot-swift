#!/bin/bash
#
# Compile the Swift sources to a mipsel object on the host, using the
# hand-patched Embedded Swift toolchain from ~/Developer/swift-embedded-ps1
# (see that repo's README for the LLVM/clang/lld patches it requires -- plain
# upstream/nightly Swift has no mipsel-none-none-elf + -mno-abicalls support).
#
# Routes through `swift-frontend -emit-ir` + a separate `llc` invocation, same
# shape as ports/N64/compile-swift.sh -- NOT plain `swiftc -c`, despite this
# toolchain's patches being able to emit the object directly that way (unlike
# N64's official Embedded-Swift MIPS slice, which has no native codegen for
# the VR4300's quirks at all). See ports/PS1/KNOWN_ISSUES.md: plain `swiftc -c`
# on this target has a confirmed bug where Array/ContiguousArray's internal
# allocation-size computation gets corrupted (garbage in the upper 16 bits of
# the byte count passed to posix_memalign); routing through `-emit-ir` + `llc`
# from the SAME patched toolchain avoids that specific bug (it's isolated to
# swiftc's integrated codegen invocation, not the LLVM MIPS backend itself).
# KNOWN_ISSUES.md documents a second, still-open bug further down Array's
# growth path (a hang on the first reallocation past an existing capacity) --
# JunkbotCore's hot-path arrays are pre-`reserveCapacity`'d (GameEngine.init,
# RenderFrame.init, Collision.swift/Input.swift's per-call working arrays) to
# avoid ever exercising that path in normal play.
#
# Phase 2 (current, see KNOWN_ISSUES.md "Update 4" + the plan doc): this port
# no longer compiles JunkbotCore's GameEngine/Collision/Input/Simulation/
# RenderList/EntityFactory/AccelerationStructures et al. -- all of them use
# Array/Dictionary in ways that hit this target's confirmed codegen bugs
# (growth past capacity, removeAll(keepingCapacity:) on an empty reserved
# array). Instead, ports/PS1/source/{GameState,PS1RenderList,FixedArray}.swift
# reimplement just the needed subset (brick/bin/junkbot only) against
# InlineArray-backed FixedArray<N, Element>, which has neither problem (no
# heap allocation, no COW, no growth at all -- confirmed working on this
# target by ~/Developer/swift-embedded-ps1's ArrayTests example).
#
# CORE_INCLUDE (not exclude, inverted from before) lists the small set of
# JunkbotCore files that ARE still compiled in: plain structs/enums and
# read-only array-literal lookup tables (populated once via a literal, never
# grown -- confirmed safe; growth *past* an initial allocation is what's
# broken, not the initial allocation itself). No `GameEngine`/`Collision`/
# `Input`/`Simulation`/`RenderList`/`EntityFactory` extension exists in this
# build at all -- `source/GameState.swift`/`PS1RenderList.swift` provide
# PS1-local equivalents instead.
CORE_INCLUDE=(Types.swift Color.swift JunkbotCore.swift PointingInputKind.swift)
GENERATED_INCLUDE=(SpriteTable.swift JunkbotKeyframes.swift)

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
REPO_ROOT=../..

core_swift=()
for f in "$REPO_ROOT"/Sources/JunkbotCore/*.swift; do
  base="$(basename "$f")"
  for inc in "${CORE_INCLUDE[@]}"; do
    [ "$base" = "$inc" ] && core_swift+=("$f")
  done
done
for f in "$REPO_ROOT"/Sources/JunkbotCore/Generated/*.swift; do
  base="$(basename "$f")"
  for inc in "${GENERATED_INCLUDE[@]}"; do
    [ "$base" = "$inc" ] && core_swift+=("$f")
  done
done

port_swift=(source/*.swift)
gen_swift=("$BUILD_DIR/SpriteAssets.swift")

echo "Compiling Swift code with host compiler..."
echo "swift-frontend: $SWIFT_FRONTEND"
echo "llc:            $LLC"
echo "Target: $SWIFT_TARGET"

echo "Step 1: Emitting LLVM IR..."
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
  "${core_swift[@]}" "${port_swift[@]}" "${gen_swift[@]}"

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

echo "✓ Swift compilation successful: $BUILD_DIR/swiftlib.o"
