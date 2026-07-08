/// Climbbot: a gray enemy with green climbing claws jutting out either side.
enum ClimbbotModel {
  static let model = Model("Climbbot") {
    Box(center: (0, 0, 0), half: (0.7, 0.7, 0.6), color: .gray)  // body
    Box(center: (-0.9, 0, 0), half: (0.2, 0.5, 0.45), color: .green)  // claws
    Box(center: (0.9, 0, 0), half: (0.2, 0.5, 0.45), color: .green)
    Box(center: (-0.3, 0.35, 0.62), half: (0.12, 0.1, 0.05), color: .dark)  // eyes
    Box(center: (0.3, 0.35, 0.62), half: (0.12, 0.1, 0.05), color: .dark)
  }
}
