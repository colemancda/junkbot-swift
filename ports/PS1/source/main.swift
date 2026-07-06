// ports/PS1/source/main.swift — Junkbot for PlayStation 1.
//
// Milestone (current): statically render a hardcoded viewport -- no
// GameEngine, no GameState, no simulation, no input, no audio -- to validate
// the sprite rendering pipeline (sprite table lookups, palette blit, VRAM
// upload) in isolation. See Renderer.swift's renderStaticViewport() and
// KNOWN_ISSUES.md "Update 5" for the bug this milestone's bisection found
// (a global `let` pointer-cast initializer hangs; fixed by computing it
// locally every frame instead).

@inline(__always)
func drawText(_ x: Int32, _ y: Int32, _ s: StaticString) {
  s.withUTF8Buffer { buf in
    buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buf.count + 1) {
      ps1_draw_text(x, y, $0)
    }
  }
}

hudDrawHook = {
  drawText(8, 8, "JUNKBOT - STATIC VIEWPORT")
}

@_cdecl("swift_main")
public func swiftMain() {
  ps1_init_heap()
  ps1_init_display()

  while true {
    ps1_begin_frame()
    renderStaticViewport()
    ps1_flip()
  }
}
