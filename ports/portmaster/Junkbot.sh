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

cd "$GAMEDIR/junkbot"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Two binaries are bundled: junkbot3.${DEVICE_ARCH} (built against SDL3/SDL3_image/SDL3_mixer)
# and junkbot2.${DEVICE_ARCH} (the same game built against the older SDL2 family). Most
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

if has_library "libSDL3.so" && has_library "libSDL3_image.so" && has_library "libSDL3_mixer.so"; then
  BINARY="junkbot3.${DEVICE_ARCH}"
else
  BINARY="junkbot2.${DEVICE_ARCH}"
fi
echo "Using $BINARY"

$GPTOKEYB "$BINARY" -c "./junkbot.gptk" &
pm_platform_helper "$GAMEDIR/junkbot/$BINARY"
"./$BINARY"

$ESUDO kill -9 $(pidof gptokeyb) 2>/dev/null
pm_finish
