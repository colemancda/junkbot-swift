//---------------------------------------------------------------------------------
// n64_umbrella.h -- single header exposed to Swift as the `CN64` module.
//
// Unlike ports/3DS and ports/NDS, Swift here does NOT import libdragon's own
// headers at all -- only this port's own shim.h/assets.h. Two reasons:
//
//   1. libdragon links with -mabi=o64 (8-byte stack slots); the Embedded Swift
//      MIPS object is o32 (4-byte stack slots) -- see build.sh's ELF-retag
//      step. Any function call that crosses the boundary with >4 register
//      arguments or any stack argument would read at the wrong offset. Every
//      bridge function below is declared with <=4 plain integer/pointer
//      arguments for exactly this reason.
//   2. LLVM (swiftc) and the N64 GCC disagree on the float-argument ABI, so no
//      float/double ever crosses this boundary either -- see shim.h for how
//      each subsystem's state (framebuffer, audio buffer, input) is instead
//      handed to Swift as a raw pointer + plain integers, with all the actual
//      per-pixel/per-sample work done in Swift.
//---------------------------------------------------------------------------------
#ifndef SWIFT_N64_UMBRELLA_H
#define SWIFT_N64_UMBRELLA_H

#include <stdint.h>
#include "shim.h"
#include "assets.h"

#endif // SWIFT_N64_UMBRELLA_H
