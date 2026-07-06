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
  var arr: [Int32] = []
  arr.reserveCapacity(10)
  drawText(8, 8, "reserveCapacity(10) ok")
  ps1_flip(); ps1_begin_frame()

  for i in 0..<8 {
    arr.append(Int32(i) * 3)
    drawText(8, 20 + Int32(i) * 12, "append ok, staying in capacity")
    ps1_flip(); ps1_begin_frame()
  }

  var sum: Int32 = 0
  for v in arr { sum &+= v }
  drawText(8, 20 + 8 * 12, "loop done, all appends succeeded")
  ps1_flip(); ps1_begin_frame()
  drawText(8, 20 + 8 * 12, "loop done, all appends succeeded")
  ps1_flip(); ps1_begin_frame()

  while true {
    ps1_begin_frame()
  }
}
