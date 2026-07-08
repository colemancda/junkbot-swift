//---------------------------------------------------------------------------------
//
//  Standalone viewer for the hand-authored low-poly 2x1 brick (BrickModel.swift).
//
//  A minimal Nintendo DS 3D "turntable": sets up the DS's fixed-function 3D
//  engine (MODE_0_3D) with one directional light and slowly spins the brick so
//  every face and stud is visible, for iterating on the model's geometry in an
//  emulator without building/running the whole game. Nothing here is wired into
//  the game itself yet.
//
//---------------------------------------------------------------------------------

import CNDS

// f32 (20.12) and DS-angle (32768 = full circle) literals, computed by hand - the libnds
// `floattof32`/`degreesToAngle` macros are function-like and don't import into Swift.
@inline(__always) func f32(_ d: Double) -> Int32 { Int32((d * 4096).rounded()) }
@inline(__always) func deg(_ d: Double) -> Int32 { Int32((d * 32768 / 360).rounded()) }

// MARK: - Video / 3D setup

videoSetMode(MODE_0_3D.rawValue)
// A texture VRAM bank must be mapped for the 3D engine even though this flat-colored model uses
// no textures (the engine still expects bank A available).
vramSetBankA(VRAM_A_TEXTURE)

glInit()
// Opaque dark slate background so the brick stands out.
glClearColor(4, 5, 8, 31)
glClearDepth(fixed12d3(GL_MAX_DEPTH))
glViewport(0, 0, 255, 191)

// Perspective projection - a spinning model reads better with perspective than the game's flat
// oblique-ortho look. 45deg vertical FOV, 256:192 aspect.
glMatrixMode(GL_PROJECTION)
glLoadIdentity()
gluPerspectivef32(deg(45), f32(256.0 / 192.0), f32(0.1), f32(40))

// Identity modelview so the light direction below is set in view space, and material shininess
// zeroed (no specular). One white directional light from the upper-front, so the top studs catch
// the most light.
glMatrixMode(GL_MODELVIEW)
glLoadIdentity()
glLight(0, RGB15(31, 31, 31), v10(154), v10(-358), v10(-307))
glMaterialShinyness()
glMaterialf(GL_SPECULAR, 0)
glMaterialf(GL_EMISSION, 0)
// Enable light 0; cull nothing for now (verify the model looks right before trusting winding).
glPolyFmt(POLY_ALPHA(31) | UInt32(POLY_CULL_NONE.rawValue) | UInt32(POLY_FORMAT_LIGHT0.rawValue))

// MARK: - Helpers

/// `RGB15`/`v10` are function-like macros; build them by hand.
@inline(__always) func RGB15(_ r: UInt16, _ g: UInt16, _ b: UInt16) -> UInt16 {
  r | (g << 5) | (b << 10)
}
@inline(__always) func v10(_ n: Int32) -> Int16 { Int16(n) }

/// A red LEGO brick, dimmed for the diffuse/ambient split (lit face ~full, shadowed ~half).
func material5(_ r: Int, _ g: Int, _ b: Int, num: Int, den: Int) -> UInt16 {
  RGB15(
    UInt16((r * num / den) >> 3), UInt16((g * num / den) >> 3), UInt16((b * num / den) >> 3))
}
let brickR = 0xC4, brickG = 0x28, brickB = 0x1C

// MARK: - Main loop

var angle: Int32 = 0

while pmMainLoop() {
  threadWaitForVBlank()

  // Turntable transform: back the camera off, tilt down slightly to see the tops, and spin.
  glMatrixMode(GL_MODELVIEW)
  glLoadIdentity()
  glTranslatef32(0, 0, f32(-5))
  glRotateXi(deg(24))
  glRotateYi(angle)

  glMaterialf(GL_DIFFUSE, material5(brickR, brickG, brickB, num: 45, den: 100))
  glMaterialf(GL_AMBIENT, material5(brickR, brickG, brickB, num: 55, den: 100))
  BrickModel.draw()

  glFlush(0)
  angle = (angle &+ 180) & 0xFFFF
}
