# libdragon build using the SDK's n64.mk. Run inside the Docker image built
# from this directory's Dockerfile (libdragon installed at $N64_INST) via
# build.sh, AFTER build.sh's host-side step has produced build/swiftlib.o
# (Embedded Swift compiled+lowered for mips-none-none-elf, ELF-retagged to
# O64 -- see build.sh / compile-swift.sh).
#
# Unlike ports/3DS/ports/NDS's single on-host `make` (devkitARM runs natively
# on macOS), libdragon's mips64-elf GCC only exists inside this directory's
# Docker image, and Embedded Swift has no mips-none-none-elf release
# toolchain -- so the Swift object is compiled on the host and linked here.
#
# Asset blobs (sprites/audio/music/font) are generated on the host by
# tools/gen_*.py + tools/LevelDump (see build.sh) into build/*.bin, then
# embedded here with `mips64-elf-objcopy -I binary` (devkitPro's bin2s, used
# by ports/3DS/ports/NDS, doesn't exist in this toolchain) -- see
# common/assets.h's doc comment for why sizes are computed as a start/end
# pointer difference instead of bin2s's `<name>_size` data word.

V = 1
BUILD_DIR = build
include $(N64_INST)/include/n64.mk

ROM       = Junkbot.z64
SWIFT_OBJ = $(BUILD_DIR)/swiftlib.o

OBJS = $(BUILD_DIR)/common/shim.o \
       $(SWIFT_OBJ) \
       $(BUILD_DIR)/sprites_bin.o \
       $(BUILD_DIR)/audio_bin.o \
       $(BUILD_DIR)/music_bin.o \
       $(BUILD_DIR)/font_bin.o

# Link the embedded Swift runtime archives (big-endian mips32, same as the
# Swift object emitted by build.sh's host-side step) plus --defsym aliases
# mapping objcopy's `_binary_<file>_{start,end}` symbols to the plain names
# common/assets.h declares.
# Note: n64.mk's own link rule already wraps every LDFLAGS entry with -Wl, --
# do not prefix these with -Wl, ourselves (see its $(patsubst %,-Wl$(COMMA)%,...)).
LDFLAGS += -L$(CURDIR)/swift-libs/mips-none-none-elf \
           -lswiftEmbeddedPlatformPOSIX \
           -lswiftExclusivitySingleThreaded \
           -lswiftUnicodeDataTables \
           --defsym=sprites_bin=_binary_sprites_bin_start \
           --defsym=sprites_bin_end=_binary_sprites_bin_end \
           --defsym=audio_bin=_binary_audio_bin_start \
           --defsym=audio_bin_end=_binary_audio_bin_end \
           --defsym=music_bin=_binary_music_bin_start \
           --defsym=music_bin_end=_binary_music_bin_end \
           --defsym=font_bin=_binary_font_bin_start \
           --defsym=font_bin_end=_binary_font_bin_end

all: $(ROM)

$(BUILD_DIR)/Junkbot.elf: $(OBJS)

$(ROM): N64_ROM_TITLE = "Junkbot"

# Embed each generated asset blob as a relocatable object (objcopy's raw
# `-I binary` mode) -- built directly from the .bin build.sh's host-side step
# already generated, no compile step of our own needed. objcopy leaves e_flags
# at 0 (no ABI/ISA markers), which the final link rejects ("linking 32-bit
# code with 64-bit code") against the o64/mips3 objects everything else in
# this build produces (compare `readelf -h`'s Flags on shim.o/swiftlib.o) --
# patch e_flags to match, the same class of fix build.sh's compile-swift.sh
# applies to the Swift object (there's no real MIPS code in these objects, so
# the flags are pure linker metadata, not a real ABI concern).
$(BUILD_DIR)/%_bin.o: $(BUILD_DIR)/%.bin
	cd $(BUILD_DIR) && $(N64_OBJCOPY) -I binary -O elf32-bigmips -B mips $(notdir $<) $(notdir $@)
	python3 -c "import sys,struct; \
p='$@'; d=bytearray(open(p,'rb').read()); \
struct.pack_into('>I', d, 0x24, 0x20002001); \
open(p,'wb').write(d)"

clean:
	rm -rf $(BUILD_DIR) $(ROM)

-include $(wildcard $(BUILD_DIR)/*.d) $(wildcard $(BUILD_DIR)/common/*.d)

.PHONY: all clean
