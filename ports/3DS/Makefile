#---------------------------------------------------------------------------------
# ports/3DS -- Nintendo 3DS port of Junkbot, built with Embedded Swift.
#
# Same shape as ports/NDS: the ARM11 binary is JunkbotCore (the shared engine,
# compiled straight from ../../Sources/JunkbotCore) plus this port's source/,
# targeting armv6-none-none-eabi (the 3DS's ARM11/ARM946E-S application CPU is
# an ARMv6K core), linked against libctru, and packaged as a homebrew .3dsx
# with 3dsxtool/smdhtool.
#
# Prerequisites:
#   - devkitPro with devkitARM and libctru (`dkp-pacman -S 3ds-dev`;
#     export DEVKITPRO=/opt/devkitpro, DEVKITARM=$DEVKITPRO/devkitARM)
#   - 3dsxtool and smdhtool (part of devkitPro's 3ds-tools/general-tools,
#     normally installed alongside 3ds-dev to $(DEVKITPRO)/tools/bin)
#   - A Swift toolchain whose Embedded stdlib ships an armv6-none-none-eabi
#     slice (as of 6.3.2, release toolchains already do -- unlike the DS port's
#     armv5te, no development snapshot is needed here).
#
# Levels are pre-parsed at build time on the host (tools/LevelDump, which runs
# JunkbotCore's real text parser + entity bridge natively) into generated
# entity-builder Swift, so the 3DS binary never parses level text -- the same
# split ports/NDS and the embedded-WASM build use, where the level parser
# stays excluded behind `#if !hasFeature(Embedded)`.
#
# Unlike the DS port, the 3DS's far larger RAM budget means sprites (including
# full background sheets, not just an average color) are embedded uncompressed
# as 16bpp RGB555 (tools/gen_assets.py), and sound effects/music are embedded
# at native sample rate as 16-bit PCM for NDSP (tools/gen_audio.py,
# tools/gen_music.py) -- no DS-style 8bpp palette or 8-bit/downsampled audio
# compromise needed. Audio conversion still shells out to macOS's `afconvert`
# to decode Ogg Vorbis, so (in addition to everything above) this build
# currently requires macOS.
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
BUILD		:=	build
REPO_ROOT	:=	../..
COMMON		:=	common/

# Override with `make CTRULIB=/path/to/libctru` to point at a libctru build
# that isn't installed under $(DEVKITPRO) (e.g. a local build/prefix).
CTRULIB		?=	$(DEVKITPRO)/libctru

PREFIX		:=	$(DEVKITARM)/bin/arm-none-eabi-
CC		:=	$(PREFIX)gcc
LD		:=	$(PREFIX)gcc

# devkitPro's 3ds-tools (3dsxtool, smdhtool) install to $(DEVKITPRO)/tools/bin,
# which a standard devkitPro environment already has on PATH.
3DSXTOOL	?=	3dsxtool
SMDHTOOL	?=	smdhtool
ICON		:=	$(CTRULIB)/default_icon.png

#---------------------------------------------------------------------------------
# code generation -- the 3DS's ARM11 application CPU, armv6k/mpcore, hard float.
#---------------------------------------------------------------------------------
ARCH		:=	-march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft

CTRUDEFS	:=	-D__3DS__ -I$(COMMON) -I$(CTRULIB)/include

CFLAGS		:=	-g -Wall -O2 -mword-relocations -ffunction-sections -fdata-sections \
			$(ARCH) $(CTRUDEFS)

LDFLAGS		:=	-specs=3dsx.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(CTRULIB)/lib

LIBS		:=	-lctru -lm

#---------------------------------------------------------------------------------
# Embedded Swift flags, targeting armv6-none-none-eabi.
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv6-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-module-name Junkbot \
			-Xcc -D__3DS__ \
			-Xcc -march=armv6k -Xcc -mtune=mpcore -Xcc -mfloat-abi=hard \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(CTRULIB)/include \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

#---------------------------------------------------------------------------------
# Sources: the shared engine + this port. Generated Swift (sprite offsets,
# level index) is emitted into $(BUILD) by tools/gen_assets.py alongside the
# asset blobs it describes.
#---------------------------------------------------------------------------------
# Font.swift is SDL-only bitmap-text layout (nothing on this port calls it);
# LevelCatalog.swift is Foundation-only text-catalog scanning (already
# `#if canImport(Foundation)`-gated, but Embedded Swift can still typecheck the
# non-Foundation half unless dropped here too).
CORE_EXCLUDE	:=	Font.swift LevelCatalog.swift
CORE_SWIFT	:=	$(filter-out $(addprefix $(REPO_ROOT)/Sources/JunkbotCore/,$(CORE_EXCLUDE)), \
			$(wildcard $(REPO_ROOT)/Sources/JunkbotCore/*.swift)) \
			$(wildcard $(REPO_ROOT)/Sources/JunkbotCore/Generated/*.swift)
PORT_SWIFT	:=	$(wildcard source/*.swift)
GEN_SWIFT	:=	$(BUILD)/SpriteAssets.swift $(BUILD)/LevelAssets.swift $(BUILD)/AudioAssets.swift \
			$(BUILD)/MusicAssets.swift
GEN_BINS	:=	$(BUILD)/sprites.bin $(BUILD)/audio.bin $(BUILD)/music.bin

OFILES		:=	$(BUILD)/junkbot.swift.o $(BUILD)/shim.o \
			$(BUILD)/sprites_bin.o $(BUILD)/audio_bin.o $(BUILD)/music_bin.o

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).3dsx

$(BUILD):
	@mkdir -p $@

# Sprite conversion: PNGs -> 16bpp RGB555 blob (bit15 = opaque) + Swift offset
# table. A stamp file stands in for the group because macOS's default make
# 3.81 predates grouped (`&:`) targets.
$(BUILD)/assets.stamp: tools/gen_assets.py \
		$(REPO_ROOT)/Sources/JunkbotCore/Generated/SpriteTable.swift | $(BUILD)
	@echo generating sprite assets
	python3 tools/gen_assets.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(BUILD)/sprites.bin $(BUILD)/SpriteAssets.swift: $(BUILD)/assets.stamp

# Audio conversion: each SoundID's clip (audio/sound-effects/, macOS's afconvert
# decodes the repo's Ogg Vorbis sources) -> signed 16bpp PCM mono blob + Swift
# offset/length/rate table, for NDSP's NDSP_FORMAT_MONO_PCM16 (see
# tools/gen_audio.py and source/Audio.swift).
$(BUILD)/audio.stamp: tools/gen_audio.py | $(BUILD)
	@echo generating audio assets
	python3 tools/gen_audio.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(BUILD)/audio.bin $(BUILD)/AudioAssets.swift: $(BUILD)/audio.stamp

# Music conversion: one loopable clip per level-music group (audio/music/) ->
# signed 16bpp PCM mono blob + Swift per-group offset/length/rate table (see
# tools/gen_music.py and source/Audio.swift).
$(BUILD)/music.stamp: tools/gen_music.py | $(BUILD)
	@echo generating music assets
	python3 tools/gen_music.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(BUILD)/music.bin $(BUILD)/MusicAssets.swift: $(BUILD)/music.stamp

# Level conversion: every campaign level, pre-parsed through JunkbotCore's own
# parser + entity bridge on the host and frozen as entity-builder Swift.
# (Level .txt files can't be listed as prerequisites -- their names contain
# spaces, which make cannot escape -- so touch the listing or `make clean`
# after editing a level in place.)
$(BUILD)/LevelAssets.swift: tools/LevelDump/Sources/LevelDump/main.swift \
		$(REPO_ROOT)/levels $(REPO_ROOT)/levels/_LEVEL_LISTING.txt | $(BUILD)
	@echo generating level assets
	swift run -c release --package-path tools/LevelDump LevelDump $(REPO_ROOT) $@

# bin2s: asset blob -> assembly -> object (bin2s ships with devkitARM generally,
# not just the DS/GBA toolchains, so this rule is identical to ports/NDS's).
$(BUILD)/%_bin.s: $(BUILD)/%.bin
	@echo bin2s $(notdir $<)
	bin2s -a 4 $< > $@

$(BUILD)/%_bin.o: $(BUILD)/%_bin.s
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

# All Swift (engine + port + generated) -> one object, whole-module.
$(BUILD)/junkbot.swift.o: $(CORE_SWIFT) $(PORT_SWIFT) $(GEN_SWIFT) \
		$(COMMON)module.modulemap $(COMMON)ctru_umbrella.h $(COMMON)shim.h $(COMMON)assets.h | $(BUILD)
	@echo compiling Swift \(engine + port\)
	$(SWIFTC) $(SWIFTFLAGS) -c $(CORE_SWIFT) $(PORT_SWIFT) $(GEN_SWIFT) -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OFILES)
	@echo linking $(notdir $@)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBS) -o $@

$(BUILD)/icon.smdh: | $(BUILD)
	@echo packaging icon
	$(SMDHTOOL) --create Junkbot "Junkbot (swift-3ds)" "junkbot-swift" $(ICON) $@

$(TARGET).3dsx: $(TARGET).elf $(BUILD)/icon.smdh
	@echo packaging $(notdir $@)
	$(3DSXTOOL) $(TARGET).elf $@ --smdh=$(BUILD)/icon.smdh

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).3dsx $(TARGET).map
