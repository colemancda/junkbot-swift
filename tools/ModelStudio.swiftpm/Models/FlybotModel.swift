/// Flybot: a small gray enemy with flat wings and a red nose.
enum FlybotModel {
  static let model = Model("Flybot") {
    Box(center: (0, 0, 0), half: (0.5, 0.4, 0.6), color: .gray)  // body
    Box(center: (-0.95, 0.1, 0), half: (0.5, 0.05, 0.5), color: .darkGray)  // wings
    Box(center: (0.95, 0.1, 0), half: (0.5, 0.05, 0.5), color: .darkGray)
    Box(center: (0, -0.05, 0.65), half: (0.16, 0.16, 0.1), color: .red)  // nose
  }
}
