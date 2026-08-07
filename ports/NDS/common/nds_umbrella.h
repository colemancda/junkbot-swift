//---------------------------------------------------------------------------------
// nds_umbrella.h -- single header exposed to Swift as the `CNDS` module.
//
// Trimmed from swift-embedded-nds's umbrella: Junkbot only needs core libnds
// (video/backgrounds/input/DMA), libc, the printf shim, and the bin2s asset
// accessors -- plus (Renderer3D.swift) videoGL.h ("NitroGL"), the DS's own
// fixed-function 3D GPU API. Already linked in (-lnds9 covers all of libnds9,
// including the 3D engine) - no wifi/keyboard headers needed.
//---------------------------------------------------------------------------------
#ifndef SWIFT_NDS_UMBRELLA_H
#define SWIFT_NDS_UMBRELLA_H

#include <nds.h>
#include <nds/arm9/videoGL.h>
#include <stdlib.h>
#include "shim.h"
#include "assets.h"

#endif // SWIFT_NDS_UMBRELLA_H
