#---------------------------------------------------------------------------------
#
# Junkbot -> Rockbox plugin for iPod Nano 2G (and other click-wheel iPods).
#
# Two-stage build:
#   1. `make swift`  -- host swiftc compiles JunkbotCore + this port's Swift into
#      one Embedded Swift object for armv4t-none-none-eabi (the Nano 2G's
#      ARM940T), audits its undefined symbols, and archives libjunkbot.a. The
#      tiny sprite offset table (build/SpriteAssets.swift) is generated first.
#   2. `make rock`   -- syncs plugin/ + libjunkbot.a into a pinned Rockbox tree
#      and runs Rockbox's own build (configure --target=ipodnano2g) to produce
#      junkbot.rock. The arm-elf-eabi-gcc cross toolchain lives in a Docker
#      volume (`make toolchain` builds it once, ~40min) because GCC 9.5 can't
#      be built with an arm64 macOS host natively.
#
#   make install IPOD=/Volumes/<name>  -- copy the .rock + sprites.bin onto a
#                                         mounted iPod.
#   make sim         -- Rockbox UI simulator build (C scaffolding + stub only).
#
# ASSETS: sprites.bin (~5.6MB RGB555 pixel data) is deliberately NOT linked into
# the .rock -- it is installed to /.rockbox/junkbot/sprites.bin and loaded into
# the audio buffer at runtime (see plugin/junkbot.c). Only the small offset
# table is compiled in.
#
#---------------------------------------------------------------------------------

ROCKBOX_SHA     := 078a506dfd0deb18165a3ed80c7fcbdb3afb0d31
SWIFT_TOOLCHAIN ?= $(HOME)/Library/Developer/Toolchains/swift-6.3.2-RELEASE.xctoolchain
SWIFTC          ?= $(SWIFT_TOOLCHAIN)/usr/bin/swiftc
NM              ?= nm
# BSD ar mangles ELF members; the Swift toolchain's llvm-ar (next to swiftc)
# emits GNU format. (:= because make predefines AR=ar, which ?= defers to.)
AR              := $(dir $(SWIFTC))llvm-ar
DOCKER          ?= docker
DOCKER_IMAGE    := debian:bookworm
DOCKER_VOLUME   := rbdev
DOCKER_APT      := build-essential texinfo flex bison wget curl xz-utils bzip2 \
                   patch file ca-certificates zip automake autoconf libtool \
                   libtool-bin perl python3

REPO_ROOT := ../..
BUILD     := build

#---------------------------------------------------------------------------------
# Embedded Swift flags: ARMv4T soft-float, importing the tiny CRockbox shim
# module. Font.swift (SDL-only text layout) and LevelCatalog.swift (Foundation
# text-catalog scanning) are excluded -- matching ports/3DS -- since nothing
# here calls them and they don't compile freestanding.
#---------------------------------------------------------------------------------
SWIFTFLAGS := -target armv4t-none-none-eabi \
              -enable-experimental-feature Embedded \
              -wmo -Osize \
              -module-name Junkbot \
              -Xcc -ffreestanding \
              -Xcc -fmodule-map-file=plugin/module.modulemap

CORE_EXCLUDE := Font.swift LevelCatalog.swift
CORE_SWIFT := $(filter-out $(addprefix $(REPO_ROOT)/Sources/JunkbotCore/,$(CORE_EXCLUDE)), \
              $(wildcard $(REPO_ROOT)/Sources/JunkbotCore/*.swift)) \
              $(wildcard $(REPO_ROOT)/Sources/JunkbotCore/Generated/*.swift)
PORT_SWIFT := $(wildcard source/*.swift)
GEN_SWIFT  := $(BUILD)/SpriteAssets.swift

.PHONY: all swift assets toolchain rockbox-tree sync rock sim run-sim install clean distclean

all: swift assets

$(BUILD):
	@mkdir -p $@

#---------------------------------------------------------------------------------
# Assets: sprites.bin (installed to the device, not linked) + SpriteAssets.swift
# (the tiny per-sprite offset table, compiled into libjunkbot.a). A stamp file
# stands in for the group because macOS's default make 3.81 predates grouped
# (`&:`) targets.
#---------------------------------------------------------------------------------
$(BUILD)/assets.stamp: tools/gen_assets.py \
		$(REPO_ROOT)/Sources/JunkbotCore/Generated/SpriteTable.swift | $(BUILD)
	@echo generating sprite assets
	python3 tools/gen_assets.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(BUILD)/SpriteAssets.swift $(BUILD)/sprites.bin: $(BUILD)/assets.stamp

assets: $(BUILD)/sprites.bin

#---------------------------------------------------------------------------------
# Stage 1: Swift -> armv4t object -> audited static archive.
# The archive is created with llvm-ar in GNU format so Rockbox's GNU ld accepts it.
#---------------------------------------------------------------------------------
$(BUILD)/junkbot.swift.o: $(CORE_SWIFT) $(PORT_SWIFT) $(GEN_SWIFT) \
		plugin/module.modulemap plugin/rockbox_shim.h | $(BUILD)
	@echo compiling Swift \(engine + port, armv4t\)
	$(SWIFTC) $(SWIFTFLAGS) -c $(CORE_SWIFT) $(PORT_SWIFT) $(GEN_SWIFT) -o $@

$(BUILD)/libjunkbot.a: $(BUILD)/junkbot.swift.o scripts/check-undefined.sh
	sh scripts/check-undefined.sh $< $(NM)
	rm -f $@
	$(AR) crs $@ $<

swift: $(BUILD)/libjunkbot.a

#---------------------------------------------------------------------------------
# Stage 2: Rockbox. GCC 9.5 (what Rockbox pins for arm-elf-eabi) can't be built
# natively on arm64 macOS, so there the toolchain and .rock build both run
# inside a Linux container (the toolchain persists in a Docker volume). On a
# native Linux host -- including CI -- neither needs Docker at all.
#---------------------------------------------------------------------------------
HOST_OS      := $(shell uname -s)
RBDEV_PREFIX ?= $(HOME)/rbdev

rockbox-tree:
	sh scripts/get-rockbox.sh $(ROCKBOX_SHA)

ifeq ($(HOST_OS),Linux)

toolchain: rockbox-tree
	mkdir -p $(RBDEV_PREFIX)/dl
	export MAKEFLAGS=-j$$(nproc); \
	yes "" | rockbox/tools/rockboxdev.sh --target=a --prefix=$(RBDEV_PREFIX) \
	    --dlwhere=$(RBDEV_PREFIX)/dl --builddir=/tmp/rbbuild

sync: rockbox-tree swift
	sh scripts/sync-plugin.sh $(abspath rockbox)

rock: swift sync
	PATH="$(RBDEV_PREFIX)/bin:$$PATH" sh -c '\
	    mkdir -p rockbox/build-nano2g && cd rockbox/build-nano2g && \
	    { [ -f Makefile ] || ../tools/configure --target=ipodnano2g --type=n; } && \
	    make -j$$(nproc) rocks && \
	    arm-elf-eabi-size apps/plugins/junkbot/junkbot.elf 2>/dev/null'
	cp rockbox/build-nano2g/apps/plugins/junkbot/junkbot.rock $(BUILD)/
	@echo "built $(BUILD)/junkbot.rock"

else

toolchain: rockbox-tree
	$(DOCKER) volume create $(DOCKER_VOLUME)
	$(DOCKER) run --rm -v $(DOCKER_VOLUME):/opt/rbdev \
	    -v $(abspath rockbox):/rockbox:ro $(DOCKER_IMAGE) bash -c '\
	    set -e; apt-get update -qq; \
	    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $(DOCKER_APT) >/dev/null; \
	    export MAKEFLAGS=-j$$(nproc); \
	    yes "" | /rockbox/tools/rockboxdev.sh --target=a --prefix=/opt/rbdev \
	        --dlwhere=/opt/rbdev/dl --builddir=/tmp/rbbuild'

sync: rockbox-tree swift
	sh scripts/sync-plugin.sh $(abspath rockbox)

rock: swift sync
	sh scripts/clean-host-tools.sh
	$(DOCKER) run --rm -v $(DOCKER_VOLUME):/opt/rbdev \
	    -v $(abspath rockbox):/rockbox $(DOCKER_IMAGE) bash -c '\
	    set -e; apt-get update -qq; \
	    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
	        build-essential perl zip unzip wget ca-certificates python3 >/dev/null; \
	    export PATH=/opt/rbdev/bin:$$PATH; \
	    mkdir -p /rockbox/build-nano2g; cd /rockbox/build-nano2g; \
	    [ -f Makefile ] || ../tools/configure --target=ipodnano2g --type=n; \
	    make -j$$(nproc) rocks; \
	    arm-elf-eabi-size apps/plugins/junkbot/junkbot.elf 2>/dev/null || true'
	cp rockbox/build-nano2g/apps/plugins/junkbot/junkbot.rock $(BUILD)/
	@echo "built $(BUILD)/junkbot.rock"

endif

# UI simulator (host build; uses junkbot_stub.c). Rockbox's configure hardcodes
# gcc-16/gcc-ar-16/cpp-16 on Darwin whenever it detects Clang, assuming Homebrew
# GCC (`brew install gcc`) is on PATH.
sim: sync
	sh scripts/clean-host-tools.sh
	mkdir -p rockbox/build-sim
	PATH="/opt/homebrew/bin:$$PATH" sh -c ' \
	    cd rockbox/build-sim && { [ -f Makefile ] || \
	        ../tools/configure --target=ipodnano2g --type=s; } && $(MAKE)'
	@# rockboxui reads plugins from simdisk/.rockbox/rocks (its simulated
	@# device root), which the plugin build alone doesn't populate.
	mkdir -p rockbox/build-sim/simdisk/.rockbox/rocks/games
	cp rockbox/build-sim/apps/plugins/junkbot/junkbot.rock \
	    rockbox/build-sim/simdisk/.rockbox/rocks/games/

run-sim: sim
	sh scripts/run-sim.sh

install: $(BUILD)/junkbot.rock $(BUILD)/sprites.bin
	@test -n "$(IPOD)" || { echo "usage: make install IPOD=/Volumes/<ipod>"; exit 1; }
	cp $(BUILD)/junkbot.rock "$(IPOD)/.rockbox/rocks/games/"
	mkdir -p "$(IPOD)/.rockbox/junkbot"
	cp $(BUILD)/sprites.bin "$(IPOD)/.rockbox/junkbot/"
	@echo "installed to $(IPOD)/.rockbox/rocks/games/junkbot.rock + $(IPOD)/.rockbox/junkbot/sprites.bin"

clean:
	rm -rf $(BUILD)

distclean: clean
	rm -rf rockbox
