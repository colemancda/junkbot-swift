#!/bin/sh
# Copy the junkbot plugin sources + prebuilt libjunkbot.a into the Rockbox tree
# and (idempotently) register the plugin in SUBDIRS/CATEGORIES.
set -e

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROCKBOX="${1:-$HERE/rockbox}"
PLUGDIR="$ROCKBOX/apps/plugins/junkbot"

[ -d "$ROCKBOX/apps/plugins" ] || {
    echo "error: no Rockbox tree at $ROCKBOX (run get-rockbox.sh first)" >&2
    exit 1
}

mkdir -p "$PLUGDIR"
cp "$HERE"/plugin/junkbot.c \
   "$HERE"/plugin/junkbot_stub.c \
   "$HERE"/plugin/rockbox_shim.c \
   "$HERE"/plugin/rockbox_shim.h \
   "$HERE"/plugin/SOURCES \
   "$HERE"/plugin/junkbot.make \
   "$PLUGDIR/"

if [ -f "$HERE/build/libjunkbot.a" ]; then
    cp "$HERE/build/libjunkbot.a" "$PLUGDIR/"
else
    echo "note: build/libjunkbot.a not present yet (fine for sim builds)"
fi

# Register in SUBDIRS (cpp-preprocessed) and CATEGORIES, once. The guard limits
# the plugin to iPod-style click-wheel targets with a >=176x132 16-bit color
# LCD -- junkbot.c hard-codes BUTTON_SCROLL_FWD/MENU/PLAY/SELECT, so it only
# compiles for the iPod keypads.
if ! grep -q '^junkbot$' "$ROCKBOX/apps/plugins/SUBDIRS"; then
    cat >> "$ROCKBOX/apps/plugins/SUBDIRS" <<'EOF'

/* Junkbot (Embedded Swift engine; see apps/plugins/junkbot) */
#if defined(HAVE_LCD_COLOR) && (LCD_DEPTH == 16) && (LCD_WIDTH >= 176) && (LCD_HEIGHT >= 132) \
    && (CONFIG_KEYPAD == IPOD_4G_PAD || CONFIG_KEYPAD == IPOD_3G_PAD \
        || CONFIG_KEYPAD == IPOD_1G2G_PAD)
junkbot
#endif
EOF
    echo "registered junkbot in SUBDIRS"
fi

if ! grep -q '^junkbot,' "$ROCKBOX/apps/plugins/CATEGORIES"; then
    echo "junkbot,games" >> "$ROCKBOX/apps/plugins/CATEGORIES"
    echo "registered junkbot in CATEGORIES"
fi

echo "plugin synced into $PLUGDIR"
