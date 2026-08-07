/// A 2x1 LEGO brick: a body box with a 2-deep x 2-wide grid of studs on top.
enum BrickModel {
  static let model = Model("2x1 Brick") {
    Box(center: (0, 0, 0), half: (1.0, 0.6, 1.0), color: .red)
    for sx in [-0.5, 0.5] {
      for sz in [-0.5, 0.5] {
        Stud(at: (sx, sz), baseY: 0.6, radius: 0.28, height: 0.16, color: .red)
      }
    }
  }
}
