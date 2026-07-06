#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

get_controls

GAMEDIR="/$directory/ports/junkbot"
CONFDIR="$GAMEDIR/conf"
mkdir -p "$CONFDIR"
export XDG_CONFIG_HOME="$CONFDIR"
export XDG_DATA_HOME="$CONFDIR"

# GAMEDIR is already the extracted junkbot/ data folder - PortMaster installs this
# script's declared items (Junkbot.sh, junkbot/) directly under ports/junkbot/, it does
# NOT nest a second junkbot/ folder inside that. `cd "$GAMEDIR/junkbot"` looked for a
# folder that was never there, so the binary launched from the wrong cwd and its
# executable-relative asset lookup failed - confirmed on real hardware (rg35xxh MUOS via
# Discord), where this surfaced as "No levels found" at startup.
cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Two binaries are bundled: junkbot-sdl3.${DEVICE_ARCH} (built against SDL3/SDL3_image/SDL3_mixer)
# and junkbot-sdl2.${DEVICE_ARCH} (the same game built against the older SDL2 family). Most
# PortMaster-supported firmwares still only ship SDL2 system-wide; newer ones (e.g. ROCKNIX)
# ship SDL3 too. Rather than requiring two separate port submissions, detect which SDL3 shared
# libraries are actually present on THIS device at launch time and pick the matching binary -
# falling back to the SDL2 build whenever SDL3 (or either of its companion libraries) is
# missing, since a binary linked against a library that isn't there won't even start.
#
# `ldconfig -p` is the normal way to ask the dynamic linker what it already knows about, but its
# cache isn't guaranteed fresh/populated on every custom firmware image, so common lib
# directories are also checked directly as a fallback.
has_library() {
  local name="$1"
  if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -q "$name"; then
    return 0
  fi
  local dir
  for dir in /usr/lib /usr/lib64 /usr/local/lib \
    /usr/lib/aarch64-linux-gnu /usr/lib/arm-linux-gnueabihf /usr/lib/x86_64-linux-gnu; do
    if compgen -G "$dir/$name*" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

SDL3_BINARY="junkbot-sdl3.${DEVICE_ARCH}"
SDL2_BINARY="junkbot-sdl2.${DEVICE_ARCH}"

if has_library "libSDL3.so" && has_library "libSDL3_image.so" && has_library "libSDL3_mixer.so"; then
  BINARY="$SDL3_BINARY"
else
  BINARY="$SDL2_BINARY"
  # This device will never be able to run the SDL3 binary (its libraries aren't present
  # and don't appear at runtime), so it's just dead weight on a handheld's limited
  # storage - delete it the first time we confirm we're falling back to SDL2. Only ever
  # removes the *other* binary, never the one about to be launched.
  if [ -f "$SDL3_BINARY" ]; then
    echo "SDL3 not found on this device - removing unused $SDL3_BINARY to save space"
    rm -f "$SDL3_BINARY"
  fi
fi
echo "Using $BINARY"

$GPTOKEYB "$BINARY" -c "./junkbot.gptk" &
pm_platform_helper "$GAMEDIR/$BINARY"
"./$BINARY"

$ESUDO kill -9 $(pidof gptokeyb) 2>/dev/null
pm_finish
