#             __________               __   ___.
#   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
#   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
#   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
#   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
#                     \/            \/     \/    \/            \/
#
# Junkbot: C plugin scaffolding + prebuilt Embedded Swift engine.
# libjunkbot.a is produced OUTSIDE this tree (armv4t-none-none-eabi, see
# ports/iPod/Makefile in the junkbot-swift repo) and copied here by its
# sync-plugin.sh. Listing a .a as a prerequisite of the .rock links it via the
# generic rule in plugins.make (same mechanic as mikmod/$(TLSFLIB)).

JUNKBOTSRCDIR := $(APPSDIR)/plugins/junkbot
JUNKBOTBUILDDIR := $(BUILDDIR)/apps/plugins/junkbot

ROCKS += $(JUNKBOTBUILDDIR)/junkbot.rock

JUNKBOT_SRC := $(call preprocess, $(JUNKBOTSRCDIR)/SOURCES)
JUNKBOT_OBJ := $(call c2obj, $(JUNKBOT_SRC))

# add source files to OTHER_SRC to get automatic dependencies
OTHER_SRC += $(JUNKBOT_SRC)

ifndef APP_TYPE
# Device build: link the Swift engine and the TLSF allocator backing its heap.
$(JUNKBOTBUILDDIR)/junkbot.rock: $(JUNKBOT_OBJ) $(JUNKBOTSRCDIR)/libjunkbot.a $(TLSFLIB)
else
# Simulator: junkbot_stub.c stands in for the ARM-only Swift objects.
$(JUNKBOTBUILDDIR)/junkbot.rock: $(JUNKBOT_OBJ)
endif
