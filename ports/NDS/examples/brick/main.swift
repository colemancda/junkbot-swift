//---------------------------------------------------------------------------------
//
//  Model gallery for the hand-authored low-poly Junkbot entity models
//  (Models.swift). A Nintendo DS "turntable": the top screen spins the current
//  model under one directional light; the bottom screen is a text console
//  showing debug info (name, part/triangle counts, a rough poly-budget note).
//  L / R cycle through the models.
//
//  Standalone - for iterating on the models in an emulator, not wired into the
//  game.
//
//---------------------------------------------------------------------------------

import CNDS

let KEY_L: UInt32 = 1 << 9
let KEY_R: UInt32 = 1 << 8

// f32 (20.12) and DS-angle (32768 = full circle) literals, computed by hand - the libnds
// `floattof32`/`degreesToAngle` macros are function-like and don't import into Swift.
@inline(__always) func f32(_ d: Double) -> Int32 { Int32((d * 4096).rounded()) }
@inline(__always) func deg(_ d: Double) -> Int32 { Int32((d * 32768 / 360).rounded()) }
@inline(__always) func rgb15(_ r: UInt16, _ g: UInt16, _ b: UInt16) -> UInt16 { r | (g << 5) | (b << 10) }

// MARK: - Bottom-screen text console (sub engine)

_ = consoleDemoInit()

/// Prints a `StaticString` through the libnds console (`nds_print_len` wraps `iprintf("%.*s")`,
/// since Embedded Swift can't call variadic `iprintf` directly - see `common/shim.h`).
func put(_ s: StaticString) {
  s.withUTF8Buffer { buf in
    guard let base = buf.baseAddress else { return }
    base.withMemoryRebound(to: CChar.self, capacity: buf.count) {
      nds_print_len($0, Int32(buf.count))
    }
  }
}

func showInfo(index: Int) {
  let model = Models.all[index]
  put("\u{1b}[2J")  // clear screen
  nds_printf_2i("\u{1b}[1;2HMODEL  %d / %d", Int32(index + 1), Int32(Models.all.count))
  put("\u{1b}[3;2H")
  model.name.withUTF8Buffer { buf in
    if let base = buf.baseAddress {
      base.withMemoryRebound(to: CChar.self, capacity: buf.count) {
        nds_print_len($0, Int32(buf.count))
      }
    }
  }
  nds_printf_1i("\u{1b}[5;2HParts:     %d", Int32(model.partCount))
  nds_printf_1i("\u{1b}[6;2HTriangles: %d", Int32(model.triangleCount))
  nds_printf_1i("\u{1b}[7;2HVertices:  %d", Int32(model.triangleCount * 3))
  // The DS geometry engine handles ~2048 polys/frame; note how many of these models fit at once.
  let budget = model.triangleCount > 0 ? 2048 / model.triangleCount : 0
  nds_printf_1i("\u{1b}[9;2H~%d fit in one frame", Int32(budget))
  put("\u{1b}[22;2HL / R  change model")
}

// MARK: - Top-screen 3D setup (main engine)

videoSetMode(MODE_0_3D.rawValue)
vramSetBankA(VRAM_A_TEXTURE)

glInit()
glClearColor(4, 5, 8, 31)
glClearDepth(fixed12d3(GL_MAX_DEPTH))
glViewport(0, 0, 255, 191)

glMatrixMode(GL_PROJECTION)
glLoadIdentity()
gluPerspectivef32(deg(45), f32(256.0 / 192.0), f32(0.1), f32(40))

// Identity modelview so the light direction is set in view space; one white directional light
// from the upper-front so tops catch the most light.
glMatrixMode(GL_MODELVIEW)
glLoadIdentity()
glLight(0, rgb15(31, 31, 31), Int16(154), Int16(-358), Int16(-307))
glMaterialShinyness()
glMaterialf(GL_SPECULAR, 0)
glMaterialf(GL_EMISSION, 0)
glPolyFmt(POLY_ALPHA(31) | UInt32(POLY_CULL_NONE.rawValue) | UInt32(POLY_FORMAT_LIGHT0.rawValue))

// MARK: - Main loop

var current = 0
var angle: Int32 = 0
showInfo(index: current)

while pmMainLoop() {
  threadWaitForVBlank()
  scanKeys()
  let pressed = keysDown()

  if pressed & KEY_R != 0 {
    current = (current + 1) % Models.all.count
    showInfo(index: current)
  }
  if pressed & KEY_L != 0 {
    current = (current + Models.all.count - 1) % Models.all.count
    showInfo(index: current)
  }

  glMatrixMode(GL_MODELVIEW)
  glLoadIdentity()
  glTranslatef32(0, 0, f32(-5))
  glRotateXi(deg(22))
  glRotateYi(angle)
  Models.all[current].mesh.draw()

  glFlush(0)
  angle = (angle &+ 170) & 0xFFFF
}
