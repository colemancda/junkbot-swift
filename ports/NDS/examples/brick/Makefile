#---------------------------------------------------------------------------------
# Standalone viewer for the hand-authored low-poly 2x1 brick (BrickModel.swift).
#
# A minimal spin-off of ../../Makefile: no JunkbotCore, no asset pipeline, just
# the two Swift files here + the shared CNDS glue (../../common/) linked against
# libnds/calico. Same armv5te-none-none-eabi Embedded Swift toolchain the main
# port needs (override with `make SWIFTC=/path/to/swiftc`).
#
#   make          build brick.nds
#   make clean
#---------------------------------------------------------------------------------
.SUFFIXES:

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitpro")
endif
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=$$DEVKITPRO/devkitARM")
endif

SWIFTC		?=	swiftc

TARGET		:=	brick
BUILD		:=	build
COMMON		:=	../../common/

LIBNDS		:=	$(DEVKITPRO)/libnds
CALICO		:=	$(DEVKITPRO)/calico

PREFIX		:=	$(DEVKITARM)/bin/arm-none-eabi-
CC		:=	$(PREFIX)gcc
LD		:=	$(PREFIX)gcc

ARCH		:=	-march=armv5te -mtune=arm946e-s -mthumb
NDSDEFS		:=	-DARM9 -D__NDS__ -I$(COMMON) -I$(LIBNDS)/include -I$(CALICO)/include
CFLAGS		:=	-g -Wall -O2 -ffunction-sections -fdata-sections $(ARCH) $(NDSDEFS)
LDFLAGS		:=	-specs=$(CALICO)/share/ds9.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(LIBNDS)/lib -L$(CALICO)/lib
LIBS		:=	-lnds9 -lcalico_ds9 -lm

SWIFTFLAGS	:=	-target armv5te-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-module-name BrickExample \
			-Xcc -DARM9 -Xcc -D__NDS__ \
			-Xcc -march=armv5te -Xcc -mfloat-abi=soft \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(LIBNDS)/include \
			-Xcc -I$(CALICO)/include \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

PORT_SWIFT	:=	BrickModel.swift main.swift
OFILES		:=	$(BUILD)/brick.swift.o $(BUILD)/shim.o
ARM7_ELF	:=	$(CALICO)/bin/ds7_maine.elf

.PHONY: all clean
all: $(TARGET).nds

$(BUILD):
	@mkdir -p $@

$(BUILD)/brick.swift.o: $(PORT_SWIFT) \
		$(COMMON)module.modulemap $(COMMON)nds_umbrella.h $(COMMON)shim.h $(COMMON)assets.h | $(BUILD)
	@echo compiling Swift
	$(SWIFTC) $(SWIFTFLAGS) -c $(PORT_SWIFT) -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OFILES)
	@echo linking $(notdir $@)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBS) -o $@

$(TARGET).nds: $(TARGET).elf
	@echo packaging $(notdir $@)
	ndstool -c $@ -9 $(TARGET).elf -7 $(ARM7_ELF) \
		-b $(CALICO)/share/nds-icon.bmp "Brick Viewer;low-poly 2x1;swift-nds"

clean:
	rm -rf $(BUILD) $(TARGET).elf $(TARGET).nds $(TARGET).map
