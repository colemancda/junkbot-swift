//---------------------------------------------------------------------------------
// nds_umbrella.h -- single header exposed to Swift as the `CNDS` module.
//
// Trimmed from swift-embedded-nds's umbrella: Junkbot only needs core libnds
// (video/backgrounds/input/DMA), libc, the printf shim, and the bin2s asset
// accessors -- no wifi/GL/keyboard headers.
//---------------------------------------------------------------------------------
#ifndef SWIFT_NDS_UMBRELLA_H
#define SWIFT_NDS_UMBRELLA_H

#include <nds.h>
#include <stdlib.h>
#include "shim.h"
#include "assets.h"

#endif // SWIFT_NDS_UMBRELLA_H
