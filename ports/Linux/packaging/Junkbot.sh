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

$GPTOKEYB "junkbot.${DEVICE_ARCH}" -c "./junkbot.gptk" &
pm_platform_helper "$GAMEDIR/junkbot/junkbot.${DEVICE_ARCH}"
"./junkbot.${DEVICE_ARCH}"

$ESUDO kill -9 $(pidof gptokeyb) 2>/dev/null
pm_finish
