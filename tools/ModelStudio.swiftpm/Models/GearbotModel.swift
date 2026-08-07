/// Gearbot: a gray enemy body with a red gear on its front and two eyes.
enum GearbotModel {
  static let model = Model("Gearbot") {
    Box(center: (0, 0, 0), half: (0.8, 0.6, 0.6), color: .gray)  // body
    Disc(center: (0, 0, 0.62), radius: 0.5, color: .darkGray)  // gear rim
    Disc(center: (0, 0, 0.64), radius: 0.26, color: .red)  // gear hub
    Box(center: (-0.3, 0.35, 0.55), half: (0.12, 0.1, 0.05), color: .dark)  // eyes
    Box(center: (0.3, 0.35, 0.55), half: (0.12, 0.1, 0.05), color: .dark)
  }
}
