# ports/PS1 — PlayStation 1 port of Junkbot, built with Embedded Swift against
# PSn00bSDK, using the hand-patched toolchain from ~/Developer/swift-embedded-ps1
# (see that repo's README for why a patched LLVM/clang/lld is required at all —
# mipsel-none-none-elf + -mno-abicalls has no stock/nightly Swift support).
#
# Swift is compiled on the host by compile-swift.sh (plain `swiftc -c`, unlike
# ports/N64 which needs a separate `llc` lowering step — this toolchain's
# patches let swiftc emit the mipsel object directly). This Makefile links
# that object plus boot.o/shim.o/generated-asset .o's against PSn00bSDK's
# static libs with ld.lld (bundled in the same patched-toolchain tree as
# swiftc — no separate C toolchain/Docker step needed for linking, unlike N64's
# libdragon which only has a Linux/Docker linker).
#
# Prerequisites:
#   - The patched toolchain built per swift-embedded-ps1's README (override
#     TOOLCHAIN/SWIFTC/CLANG/LLD/OBJCOPY if it isn't at the default path).
#   - PSn00bSDK headers + .a libs at psn00bsdk/ (see `make setup-sdk`).

.DEFAULT_GOAL := all

TOOLCHAIN ?= /Volumes/Crucial-2TB/Developer/build/Ninja-ReleaseAssert
SWIFTC    ?= $(TOOLCHAIN)/swift-macosx-arm64/bin/swiftc
CLANG     ?= $(TOOLCHAIN)/llvm-macosx-arm64/bin/clang
LLD       ?= $(TOOLCHAIN)/llvm-macosx-arm64/bin/ld.lld
OBJCOPY   ?= $(TOOLCHAIN)/llvm-macosx-arm64/bin/llvm-objcopy
PYTHON    ?= python3

SDK            := psn00bsdk
PSN00BSDK_INC  := $(SDK)/include
SDK_IMAGE      := nahimr/psn00bsdk_docker_mipsel
SWIFT_EMBEDDED_LIBS := $(TOOLCHAIN)/swift-macosx-arm64/lib/swift/embedded/mipsel-none-none-elf

BUILD_DIR := build
ROM       := Junkbot.psexe
LOAD_ADDR := 0x80010000

CLANG_TARGET = mipsel-none-elf
CLANG_FLAGS = \
    --target=$(CLANG_TARGET) \
    -march=mips1 \
    -mabi=o32 \
    -mno-abicalls \
    -fno-pic \
    -msoft-float \
    -G0 \
    -I$(PSN00BSDK_INC) \
    -Icommon \
    -c

SWIFT_RUNTIME_LIBS = \
    $(SWIFT_EMBEDDED_LIBS)/libswiftEmbeddedPlatformPOSIX.a \
    $(SWIFT_EMBEDDED_LIBS)/libswiftExclusivitySingleThreaded.a

PSN00B_LIBS = \
    $(SDK)/libpsxgpu.a \
    $(SDK)/libpsxapi.a \
    $(SDK)/libpsxetc.a \
    $(SDK)/libpsxgte.a \
    $(SDK)/libpsxsio.a \
    $(SDK)/libpsxspu.a \
    $(SDK)/libc.a

LLD_FLAGS = \
    -m elf32ltsmip \
    -T Support/psexe.ld \
    --no-eh-frame-hdr \
    --allow-multiple-definition \
    -nostdlib

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/boot.o: Support/boot.S | $(BUILD_DIR)
	$(CLANG) $(CLANG_FLAGS) -o $@ $<

$(BUILD_DIR)/shim.o: common/shim.c common/shim.h | $(BUILD_DIR)
	$(CLANG) $(CLANG_FLAGS) -o $@ common/shim.c

# Swift object: compiled by compile-swift.sh, not a Make recipe, since it
# needs SWIFTC/TOOLCHAIN env passthrough and the CORE_EXCLUDE/GENERATED_EXCLUDE
# file-list logic (see that script). Always re-run it; it's fast and this
# keeps Make from needing to replicate its source-file globbing.
.PHONY: $(BUILD_DIR)/swiftlib.o
$(BUILD_DIR)/swiftlib.o: | $(BUILD_DIR)
	SWIFTC=$(SWIFTC) TOOLCHAIN=$(TOOLCHAIN) BUILD_DIR=$(BUILD_DIR) ./compile-swift.sh

$(BUILD_DIR)/out.elf: $(BUILD_DIR)/boot.o $(BUILD_DIR)/shim.o $(BUILD_DIR)/swiftlib.o Support/psexe.ld
	$(LLD) $(LLD_FLAGS) -o $@ \
	    $(BUILD_DIR)/boot.o \
	    $(BUILD_DIR)/shim.o \
	    $(BUILD_DIR)/swiftlib.o \
	    $(SWIFT_RUNTIME_LIBS) \
	    $(PSN00B_LIBS)

$(BUILD_DIR)/out.bin: $(BUILD_DIR)/out.elf
	$(OBJCOPY) -O binary $< $@

$(ROM): $(BUILD_DIR)/out.bin Support/elf2psexe.py
	$(PYTHON) Support/elf2psexe.py $< $@ $(LOAD_ADDR)
	@echo "  ✓  $(ROM)"

.PHONY: all clean setup-sdk check-sdk

all: $(ROM)

setup-sdk:
	@echo "Pulling $(SDK_IMAGE)..."
	docker pull $(SDK_IMAGE)
	mkdir -p $(SDK)/include
	docker run --rm \
	    -v $(CURDIR)/$(SDK):/out \
	    $(SDK_IMAGE) \
	    sh -c "cp -r /usr/local/PSN00BSDK_LIBS/include/. /out/include/ && \
	           cp /usr/local/PSN00BSDK_LIBS/*.a /out/"
	@echo "SDK ready at $(SDK)/"

check-sdk:
	@test -f "$(PSN00BSDK_INC)/psxgpu.h" || \
	    { echo "ERROR: psxgpu.h not found — run: make setup-sdk"; exit 1; }
	@echo "SDK OK: $(PSN00BSDK_INC)"

clean:
	rm -rf $(BUILD_DIR) $(ROM)
