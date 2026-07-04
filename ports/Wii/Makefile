# Wii port - a minimal scaffold, not a full port (see Sources/JunkbotWii/main.swift's doc
# comment). Built against libogc/GX with devkitPPC, using Embedded Swift the same way
# https://github.com/MillerTechnologyPeru/swift-embedded-wii's examples are: `swiftc -target
# powerpc-none-none-eabi -enable-experimental-feature Embedded -wmo`, no SwiftPM. That means
# JunkbotCore can't be `import`ed as a prebuilt module like every other port does - instead this
# whole-module-compiles JunkbotCore's own sources together with Sources/JunkbotWii/main.swift as
# one flat build (see SOURCES below).
#
# Requires a Swift toolchain patched for PowerPC (PPC32SwiftABIInfo in clang/LLVM, plus an
# embedded stdlib for powerpc-none-none-eabi) - see that repo's README for how to build one; there
# is no prebuilt download. Override SWIFTC to point at it:
#   make -C ports/Wii build SWIFTC=/path/to/build/swift-macosx-arm64/bin/swiftc

.PHONY: build clean run dolphin

DEVKITPRO       ?= /opt/devkitpro
DEVKITPPC       ?= $(DEVKITPRO)/devkitPPC
LIBOGC          := $(DEVKITPRO)/libogc
LIBOGC_INC      := $(LIBOGC)/include
LIBOGC_LIB      := $(LIBOGC)/lib/wii

SWIFT_TOOLCHAIN ?= $(HOME)/Library/Developer/Toolchains/swift-latest.xctoolchain
SWIFTC          ?= $(SWIFT_TOOLCHAIN)/usr/bin/swiftc

PREFIX          := $(DEVKITPPC)/bin/powerpc-eabi-
CC              := $(PREFIX)gcc
ELF2DOL         := $(DEVKITPRO)/tools/bin/elf2dol
WIILOAD         ?= $(DEVKITPRO)/tools/bin/wiiload

TARGET          := JunkbotWii
BUILD           := build
BRIDGING_HEADER := Support/BridgingHeader.h

# An explicit allowlist, not "every JunkbotCore file minus a few exclusions": this scaffold only
# needs the simulation core (GameEngine + its extensions), not level text I/O (LevelCatalog.swift/
# Level*.swift need Foundation and/or pull in Unicode normalization tables that don't link under
# Embedded Swift - see LevelText.swift's own note; this scaffold builds one hardcoded level
# instead, Sources/JunkbotWii/main.swift's buildLevel()) or the sprite/text rendering support
# (RenderList/RenderCommand/SpriteLookup/Generated/Font/Camera/Button/PointingInputKind/Color/
# GameRenderer/Rendering.swift - irrelevant to this scaffold's flat-colored-quad renderer). Embedded
# Swift's dead-code stripping does not reliably prune unreachable `public` API on its own (verified
# empirically: including Font.swift alone, despite nothing calling it, pulled in Unicode grapheme-
# breaking/case-mapping tables that fail to link for powerpc-none-none-eabi), so keep this list
# tight rather than relying on that.
CORE_DIR        := ../../Sources/JunkbotCore
CORE_SOURCES    := \
	$(CORE_DIR)/AccelerationStructures.swift \
	$(CORE_DIR)/Collision.swift \
	$(CORE_DIR)/EntityFactory.swift \
	$(CORE_DIR)/GameEngine.swift \
	$(CORE_DIR)/Input.swift \
	$(CORE_DIR)/JunkbotCore.swift \
	$(CORE_DIR)/Simulation.swift \
	$(CORE_DIR)/Snapshot.swift \
	$(CORE_DIR)/Types.swift \
	$(CORE_DIR)/Undo.swift
SOURCES         := $(CORE_SOURCES) Sources/JunkbotWii/CoreCompat.swift Sources/JunkbotWii/main.swift

MACHDEP         := -DGEKKO -mrvl -mcpu=750 -meabi -mhard-float

SWIFT_FLAGS     := \
	-target powerpc-none-none-eabi \
	-enable-experimental-feature Embedded \
	-wmo -Osize -parse-as-library \
	-import-objc-header $(BRIDGING_HEADER) \
	-Xcc -DGEKKO -Xcc -DHW_RVL \
	-Xcc -I$(LIBOGC_INC) \
	-Xcc -I$(DEVKITPPC)/powerpc-eabi/include

LDFLAGS         := -g $(MACHDEP) -Wl,-Map,$(BUILD)/$(TARGET).map
LIBS            := -lwiiuse -lbte -logc -lm

SHIM_OBJS       := $(BUILD)/shims.o

build: $(TARGET).dol

$(BUILD):
	mkdir -p $@

# All of JunkbotCore plus main.swift compile as a single whole-module invocation (there's no
# separate JunkbotCore.swiftmodule here - see this file's header comment), so any change to either
# side re-triggers the whole thing; that's fine at this project's size.
$(BUILD)/main.o: $(SOURCES) $(BRIDGING_HEADER) | $(BUILD)
	$(SWIFTC) $(SWIFT_FLAGS) -emit-object -o $@ $(SOURCES)

$(BUILD)/%.o: Support/%.c | $(BUILD)
	$(CC) $(MACHDEP) -O2 -I$(LIBOGC_INC) -c $< -o $@

$(TARGET).elf: $(BUILD)/main.o $(SHIM_OBJS)
	$(CC) $(LDFLAGS) $(BUILD)/main.o $(SHIM_OBJS) -L$(LIBOGC_LIB) $(LIBS) -o $@

$(TARGET).dol: $(TARGET).elf
	$(ELF2DOL) $< $@

run: $(TARGET).dol
	$(WIILOAD) $(TARGET).dol

dolphin: $(TARGET).dol
	open -a Dolphin $(TARGET).dol

clean:
	rm -rf $(BUILD) $(TARGET).elf $(TARGET).dol
