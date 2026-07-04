//---------------------------------------------------------------------------------
// ctru_umbrella.h -- single header exposed to Swift as the `CTRU` module.
//
// Junkbot only needs core libctru (gfx/hid/apt/ndsp/console) -- no romfs, soc,
// or GPU (citro2d/citro3d) headers, since the bottom screen is a hand-rolled
// software rasterizer straight into the LCD framebuffer (see source/Renderer.swift).
//---------------------------------------------------------------------------------
#ifndef SWIFT_3DS_UMBRELLA_H
#define SWIFT_3DS_UMBRELLA_H

#include <3ds.h>
#include <stdlib.h>
#include "shim.h"
#include "assets.h"

#endif // SWIFT_3DS_UMBRELLA_H
