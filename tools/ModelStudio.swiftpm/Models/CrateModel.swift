/// Crate: a tan pushable box framed with brown corner posts and top/bottom rims.
enum CrateModel {
  static let model = Model("Crate") {
    Box(center: (0, 0, 0), half: (0.9, 0.9, 0.9), color: .tan)  // body
    for sx in [-0.85, 0.85] {
      for sz in [-0.85, 0.85] {
        Box(center: (sx, 0, sz), half: (0.1, 0.9, 0.1), color: .brown)  // corner posts
      }
    }
    Box(center: (0, 0.9, 0), half: (0.95, 0.06, 0.95), color: .brown)  // top rim
    Box(center: (0, -0.9, 0), half: (0.95, 0.06, 0.95), color: .brown)  // bottom rim
  }
}
