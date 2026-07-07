#!/bin/bash
#
# Compile the Swift sources to a mipsel object on the host, using the
# hand-patched Embedded Swift toolchain from ~/Developer/swift-embedded-ps1
# (see that repo's README for the LLVM/clang/lld patches it requires -- plain
# upstream/nightly Swift has no mipsel-none-none-elf + -mno-abicalls support).
#
# Routes through `swift-frontend -emit-ir` + a separate `llc` invocation, same
# shape as ports/N64/compile-swift.sh -- NOT plain `swiftc -c`.
#
# KNOWN_ISSUES.md documents this port's debugging history in full, but the
# short version: everything that looked like an "Array/Dictionary codegen
# bug" on this target (growth past capacity hanging, removeAll hanging, a
# ternary between two global Arrays hanging) turned out to be ONE root
# cause -- `swift_retain`/`swift_release` compile to real atomic
# read-modify-write instructions (LLVM IR `atomicrmw`), which the Mips
# backend lowers to `ll`/`sc` (Load-Linked/Store-Conditional). Those
# instructions don't exist on MIPS-I (the PS1's R3000A) even though we build
# with `-mcpu=mips1`; on this target `sc` never reports success, so the
# retry loop spins forever. `-assume-single-threaded` (below) makes Swift's
# frontend emit non-atomic retain/release instead, which fixed every one of
# those hangs. With that fixed, the full shared `JunkbotCore` (`GameEngine`,
# `Collision`, `Input`, `Simulation`, `RenderList`, `EntityFactory`,
# `AccelerationStructures`) works the same as it does on every other port --
# no PS1-local `GameState`/`FixedArray`/`PS1DynArray` reimplementation needed
# anymore (removed; see git history if you need to resurrect that approach).
#
# CORE_EXCLUDE/GENERATED_EXCLUDE mirror ports/N64/compile-swift.sh's list and
# reasoning: Font.swift/LevelCatalog.swift are Foundation-dependent (this
# port doesn't need on-device text rendering or catalog scanning yet);
# UndercoverLevelData.swift/LevelData.swift are the Undercover Exclusive
# campaign, unused by this v1 port's base-campaign scope. Additionally (PS1-
# specific, tighter budget than N64's 4MB RDRAM): JunkbotLevelData.swift (the
# ~700KB base-campaign generated data) is excluded too, since this v1 port
# still uses a small hand-built test level (source/main.swift) rather than
# the full campaign -- once campaign support lands here, drop it from this
# list the same way N64 keeps its own campaign file in.
CORE_EXCLUDE=(Font.swift LevelCatalog.swift)
GENERATED_EXCLUDE=(UndercoverLevelData.swift LevelData.swift JunkbotLevelData.swift)

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
gen_swift=("$BUILD_DIR/SpriteAssets.swift")

echo "Compiling Swift code with host compiler..."
echo "swift-frontend: $SWIFT_FRONTEND"
echo "llc:            $LLC"
echo "Target: $SWIFT_TARGET"

echo "Step 1: Emitting LLVM IR..."
"$SWIFT_FRONTEND" -frontend \
  -target "$SWIFT_TARGET" \
  -enable-experimental-feature Embedded \
  -assume-single-threaded \
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

echo "Step 1.5: Rewriting atomic RMW/cmpxchg IR to plain non-atomic ops (see KNOWN_ISSUES.md -- ll/sc don't exist on MIPS-I, and -assume-single-threaded only covers a few weak_odr entry points, not every inlined refcount/uniqueness check)..."
python3 "$SCRIPT_DIR/Support/fix_atomics.py" "$BUILD_DIR/swiftlib.ll" "$BUILD_DIR/swiftlib.fixed.ll"

echo "Step 2: Lowering IR to object with llc (mips1, noabicalls, static)..."
"$LLC" \
  -mtriple=mipsel-none-none-elf \
  -mcpu=mips1 \
  -mattr=+noabicalls,+soft-float \
  -relocation-model=static \
  -filetype=obj \
  -o "$BUILD_DIR/swiftlib.o" \
  "$BUILD_DIR/swiftlib.fixed.ll"

if [ ! -f "$BUILD_DIR/swiftlib.o" ]; then
  echo "✗ llc lowering failed"
  exit 1
fi

echo "✓ Swift compilation successful: $BUILD_DIR/swiftlib.o"
