/// Shield: a thin cyan panel with a white emblem on the front.
enum ShieldModel {
  static let model = Model("Shield") {
    Box(center: (0, 0, 0), half: (0.85, 1.0, 0.12), color: .cyan)  // panel
    Box(center: (0, 0, 0.13), half: (0.5, 0.65, 0.03), color: .white)  // emblem
  }
}
