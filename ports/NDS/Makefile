#---------------------------------------------------------------------------------
# ports/NDS -- Nintendo DS port of Junkbot, built with Embedded Swift.
#
# Build system modeled on MillerTechnologyPeru/swift-embedded-nds's common.mk:
# the ARM9 binary is JunkbotCore (the shared engine, compiled straight from
# ../../Sources/JunkbotCore) plus this port's source/, targeting
# armv4t-none-none-eabi (the prebuilt Embedded stdlib's closest slice to the
# DS's ARM946E-S), linked against calico-based libnds, and packaged with
# ndstool using calico's prebuilt ARM7.
#
# Prerequisites:
#   - devkitPro with devkitARM, libnds, calico, ndstool, bin2s
#     (export DEVKITPRO=/opt/devkitpro, DEVKITARM=$DEVKITPRO/devkitARM)
#   - A Swift toolchain whose Embedded stdlib ships an armv4t-none-none-eabi
#     slice (swift.org 6.3.2 release or a recent main snapshot). Override with
#     `make SWIFTC=/path/to/swiftc` if the default `swiftc` lacks it.
#
# Unlike the embedded-WASM build, this target CAN link full-Unicode String
# support (libswiftUnicodeDataTables.a ships for armv4t), so the on-device
# build re-enables the level text parser via -D JUNKBOT_HAS_UNICODE_TABLES --
# see Sources/JunkbotCore/LevelParse.swift's gate.
#---------------------------------------------------------------------------------
.SUFFIXES:

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitpro")
endif
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=$$DEVKITPRO/devkitARM")
endif

SWIFTC		?=	swiftc

TARGET		:=	Junkbot
NDS_TITLE	:=	Junkbot
NDS_SUBTITLE	:=	swift-nds
BUILD		:=	build
REPO_ROOT	:=	../..
COMMON		:=	common/

LIBNDS		:=	$(DEVKITPRO)/libnds
CALICO		:=	$(DEVKITPRO)/calico

PREFIX		:=	$(DEVKITARM)/bin/arm-none-eabi-
CC		:=	$(PREFIX)gcc
LD		:=	$(PREFIX)gcc

# The Embedded stdlib's armv4t static libraries (unicode data tables live here).
SWIFT_EMBEDDED_LIBDIR := $(shell $(SWIFTC) -print-target-info -target arm64-apple-macosx14.0 2>/dev/null | sed -n 's/.*"runtimeResourcePath": "\(.*\)".*/\1/p')/embedded/armv4t-none-none-eabi

#---------------------------------------------------------------------------------
# code generation -- ARM946E-S / armv5te, soft float, no FPU.
#---------------------------------------------------------------------------------
ARCH		:=	-march=armv5te -mtune=arm946e-s -mthumb

NDSDEFS		:=	-DARM9 -D__NDS__ -I$(COMMON) \
			-I$(LIBNDS)/include -I$(CALICO)/include

CFLAGS		:=	-g -Wall -O2 -ffunction-sections -fdata-sections $(ARCH) \
			$(NDSDEFS)

LDFLAGS		:=	-specs=$(CALICO)/share/ds9.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(LIBNDS)/lib -L$(CALICO)/lib \
			-L$(SWIFT_EMBEDDED_LIBDIR)

LIBS		:=	-lswiftUnicodeDataTables -lnds9 -lcalico_ds9 -lm

#---------------------------------------------------------------------------------
# Embedded Swift flags. The prebuilt Embedded stdlib ships an armv4t slice but
# no armv5te slice; armv4t code runs fine on the ARM946E-S.
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv4t-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-D JUNKBOT_HAS_UNICODE_TABLES \
			-module-name Junkbot \
			-Xcc -DARM9 -Xcc -D__NDS__ \
			-Xcc -march=armv5te -Xcc -mfloat-abi=soft \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(LIBNDS)/include \
			-Xcc -I$(CALICO)/include \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

#---------------------------------------------------------------------------------
# Sources: the shared engine + this port. Generated Swift (sprite offsets,
# level index) is emitted into $(BUILD) by tools/gen_assets.py alongside the
# asset blobs it describes.
#---------------------------------------------------------------------------------
CORE_SWIFT	:=	$(wildcard $(REPO_ROOT)/Sources/JunkbotCore/*.swift) \
			$(wildcard $(REPO_ROOT)/Sources/JunkbotCore/Generated/*.swift)
PORT_SWIFT	:=	$(wildcard source/*.swift)
GEN_SWIFT	:=	$(BUILD)/SpriteAssets.swift $(BUILD)/LevelAssets.swift
GEN_BINS	:=	$(BUILD)/sprites.bin $(BUILD)/levels.bin

OFILES		:=	$(BUILD)/junkbot.swift.o $(BUILD)/shim.o \
			$(BUILD)/sprites_bin.o $(BUILD)/levels_bin.o

ARM7_ELF	:=	$(CALICO)/bin/ds7_maine.elf

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).nds

$(BUILD):
	@mkdir -p $@

# Asset generation: sprite PNGs -> RGB555+A1 blob + Swift offset table;
# level .txt files (in _LEVEL_LISTING.txt order) -> UTF-8 blob + Swift index.
# One invocation produces all four outputs; a stamp file stands in for the
# group because macOS's default make 3.81 predates grouped (`&:`) targets.
$(BUILD)/assets.stamp: tools/gen_assets.py \
		$(REPO_ROOT)/Sources/JunkbotCore/Generated/SpriteTable.swift | $(BUILD)
	@echo generating assets
	python3 tools/gen_assets.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(GEN_BINS) $(GEN_SWIFT): $(BUILD)/assets.stamp

# bin2s: asset blob -> assembly -> object
$(BUILD)/%_bin.s: $(BUILD)/%.bin
	@echo bin2s $(notdir $<)
	bin2s -a 4 $< > $@

$(BUILD)/%_bin.o: $(BUILD)/%_bin.s
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

# All Swift (engine + port + generated) -> one object, whole-module.
$(BUILD)/junkbot.swift.o: $(CORE_SWIFT) $(PORT_SWIFT) $(GEN_SWIFT) \
		$(COMMON)module.modulemap $(COMMON)nds_umbrella.h $(COMMON)shim.h $(COMMON)assets.h | $(BUILD)
	@echo compiling Swift \(engine + port\)
	$(SWIFTC) $(SWIFTFLAGS) -c $(CORE_SWIFT) $(PORT_SWIFT) $(GEN_SWIFT) -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OFILES)
	@echo linking $(notdir $@)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBS) -o $@

$(TARGET).nds: $(TARGET).elf
	@echo packaging $(notdir $@)
	ndstool -c $@ -9 $(TARGET).elf -7 $(ARM7_ELF) \
		-b $(CALICO)/share/nds-icon.bmp "$(NDS_TITLE);$(NDS_SUBTITLE);swift-nds"

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).nds $(TARGET).map
