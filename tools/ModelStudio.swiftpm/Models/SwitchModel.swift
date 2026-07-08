/// Switch: a gray base with a red lever and knob.
enum SwitchModel {
  static let model = Model("Switch") {
    Box(center: (0, -0.5, 0), half: (0.5, 0.25, 0.5), color: .gray)  // base
    Box(center: (0.18, 0.1, 0), half: (0.09, 0.55, 0.09), color: .red)  // lever
    CylinderY(center: (0.18, 0.45, 0), radius: 0.14, halfHeight: 0.1, color: .red)  // knob
  }
}
