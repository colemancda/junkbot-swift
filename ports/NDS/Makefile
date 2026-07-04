#---------------------------------------------------------------------------------
# ports/NDS -- Nintendo DS port of Junkbot, built with Embedded Swift.
#
# Build system modeled on MillerTechnologyPeru/swift-embedded-nds's common.mk:
# the ARM9 binary is JunkbotCore (the shared engine, compiled straight from
# ../../Sources/JunkbotCore) plus this port's source/, targeting
# armv5te-none-none-eabi (an exact match for the DS's ARM946E-S, not just the
# armv4t-backwards-compatible slice release toolchains ship), linked against
# calico-based libnds, and packaged with ndstool using calico's prebuilt ARM7.
#
# Prerequisites:
#   - devkitPro with devkitARM, libnds, calico, ndstool, bin2s
#     (export DEVKITPRO=/opt/devkitpro, DEVKITARM=$DEVKITPRO/devkitARM)
#   - A Swift toolchain whose Embedded stdlib ships an armv5te-none-none-eabi
#     slice. Release toolchains (as of 6.3.2) only ship armv4t; a recent
#     `main` development snapshot is needed for the armv5te slice this
#     Makefile targets. Override with `make SWIFTC=/path/to/swiftc` to point
#     at one.
#
# Levels are pre-parsed at build time on the host (tools/LevelDump, which runs
# JunkbotCore's real text parser + entity bridge natively) into generated
# entity-builder Swift, so the DS binary never parses level text -- the same
# split the embedded-WASM build uses, where the level parser stays excluded
# behind `#if !hasFeature(Embedded)`.
#
# Sound effects and music are similarly pre-converted at build time
# (tools/gen_audio.py, tools/gen_music.py) from the repo's Ogg Vorbis/WAV
# sources to signed 8-bit PCM, played directly by libnds/calico's
# soundPlaySample - no on-device decoder, no maxmod soundbank/streaming
# (music is one hardware-looped clip per level, not a real streaming player -
# see source/Audio.swift). The top screen's bitmap font is likewise
# pre-converted (tools/gen_font.py) from font/font.png into an ASCII-byte
# glyph table - see source/TextRenderer.swift for why that isn't just
# Sources/JunkbotCore/Font.swift's own API. These conversion steps shell out
# to macOS's `afconvert`/`sips`, so (in addition to everything above) this
# build currently requires macOS.
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
			-L$(LIBNDS)/lib -L$(CALICO)/lib

LIBS		:=	-lnds9 -lcalico_ds9 -lm

#---------------------------------------------------------------------------------
# Embedded Swift flags, targeting armv5te-none-none-eabi (needs a toolchain
# whose Embedded stdlib ships that slice - see the prerequisites note above).
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv5te-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
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
# Font.swift is SDL-only bitmap-text layout (nothing on this port calls it);
# LevelCatalog.swift is Foundation-only text-catalog scanning (already
# `#if canImport(Foundation)`-gated, but Embedded Swift can still typecheck the
# non-Foundation half unless dropped here too). Both are dead weight this
# port's cruder devkitARM link doesn't strip on its own the way the WASM
# build's linker does; excluding them saves real ROM budget.
CORE_EXCLUDE	:=	Font.swift LevelCatalog.swift
CORE_SWIFT	:=	$(filter-out $(addprefix $(REPO_ROOT)/Sources/JunkbotCore/,$(CORE_EXCLUDE)), \
			$(wildcard $(REPO_ROOT)/Sources/JunkbotCore/*.swift)) \
			$(wildcard $(REPO_ROOT)/Sources/JunkbotCore/Generated/*.swift)
PORT_SWIFT	:=	$(wildcard source/*.swift)
GEN_SWIFT	:=	$(BUILD)/SpriteAssets.swift $(BUILD)/LevelAssets.swift $(BUILD)/AudioAssets.swift \
			$(BUILD)/MusicAssets.swift $(BUILD)/FontAssets.swift
GEN_BINS	:=	$(BUILD)/sprites.bin $(BUILD)/audio.bin $(BUILD)/music.bin $(BUILD)/font.bin

OFILES		:=	$(BUILD)/junkbot.swift.o $(BUILD)/shim.o \
			$(BUILD)/sprites_bin.o $(BUILD)/audio_bin.o $(BUILD)/music_bin.o \
			$(BUILD)/font_bin.o

ARM7_ELF	:=	$(CALICO)/bin/ds7_maine.elf

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).nds

$(BUILD):
	@mkdir -p $@

# Sprite conversion: PNGs -> 8bpp palette-index blob + Swift offset/palette
# tables. One invocation produces both outputs; a stamp file stands in for the
# group because macOS's default make 3.81 predates grouped (`&:`) targets.
$(BUILD)/assets.stamp: tools/gen_assets.py \
		$(REPO_ROOT)/Sources/JunkbotCore/Generated/SpriteTable.swift | $(BUILD)
	@echo generating sprite assets
	python3 tools/gen_assets.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(BUILD)/sprites.bin $(BUILD)/SpriteAssets.swift: $(BUILD)/assets.stamp

# Audio conversion: each SoundID's clip (audio/sound-effects/, macOS's afconvert
# decodes the repo's Ogg Vorbis sources) -> signed 8bpp PCM mono blob + Swift
# offset/length/rate table, for libnds/calico's soundPlaySample (no maxmod
# soundbank - see tools/gen_audio.py and source/Audio.swift).
$(BUILD)/audio.stamp: tools/gen_audio.py | $(BUILD)
	@echo generating audio assets
	python3 tools/gen_audio.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(BUILD)/audio.bin $(BUILD)/AudioAssets.swift: $(BUILD)/audio.stamp

# Music conversion: one loopable clip per level-music group (audio/music/,
# downsampled to 8kHz to fit budget) -> signed 8bpp PCM mono blob + Swift
# per-group offset/length table (see tools/gen_music.py and source/Audio.swift).
$(BUILD)/music.stamp: tools/gen_music.py | $(BUILD)
	@echo generating music assets
	python3 tools/gen_music.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(BUILD)/music.bin $(BUILD)/MusicAssets.swift: $(BUILD)/music.stamp

# Font conversion: font/font.png (the same proportional bitmap font every
# other port draws) -> a 1bpp atlas blob + ASCII-byte-indexed Swift glyph
# table, for the top screen's info panel (see tools/gen_font.py and
# source/TextRenderer.swift).
$(BUILD)/font.stamp: tools/gen_font.py $(REPO_ROOT)/font/font.png | $(BUILD)
	@echo generating font assets
	python3 tools/gen_font.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(BUILD)/font.bin $(BUILD)/FontAssets.swift: $(BUILD)/font.stamp

# Level conversion: every campaign level, pre-parsed through JunkbotCore's own
# parser + entity bridge on the host and frozen as entity-builder Swift.
# (Level .txt files can't be listed as prerequisites -- their names contain
# spaces, which make cannot escape -- so touch the listing or `make clean`
# after editing a level in place.)
$(BUILD)/LevelAssets.swift: tools/LevelDump/Sources/LevelDump/main.swift \
		$(REPO_ROOT)/levels $(REPO_ROOT)/levels/_LEVEL_LISTING.txt | $(BUILD)
	@echo generating level assets
	swift run -c release --package-path tools/LevelDump LevelDump $(REPO_ROOT) $@

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
