// ports/PS1/source/main.swift — Junkbot for PlayStation 1.
//
// Milestone 1 (this file, for now): prove the ported toolchain/build plumbing
// works end-to-end from ports/PS1 (not just the original swift-embedded-ps1
// examples) by booting to a debug-font text screen. JunkbotCore + the real
// game loop land in later milestones (see /Users/coleman/.claude/plans -
// zesty-inventing-pancake.md).

@inline(__always)
func drawText(_ x: Int32, _ y: Int32, _ s: StaticString) {
  s.withUTF8Buffer { buf in
    buf.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buf.count + 1) {
      ps1_draw_text(x, y, $0)
    }
  }
}

@_cdecl("swift_main")
public func swiftMain() {
  ps1_init_heap()
  ps1_init_display()
  while true {
    ps1_begin_frame()
    drawText(8, 8, "Junkbot for PlayStation 1")
    drawText(8, 24, "Embedded Swift + PSn00bSDK")
    ps1_flip()
  }
}
