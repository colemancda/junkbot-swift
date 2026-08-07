/// Jump: a gray base, three white spring coils, and a green top pad.
enum JumpModel {
  static let model = Model("Jump") {
    Box(center: (0, -0.75, 0), half: (0.7, 0.15, 0.6), color: .gray)  // base
    CylinderY(center: (0, -0.35, 0), radius: 0.4, halfHeight: 0.08, color: .white)  // coils
    CylinderY(center: (0, -0.05, 0), radius: 0.4, halfHeight: 0.08, color: .white)
    CylinderY(center: (0, 0.25, 0), radius: 0.4, halfHeight: 0.08, color: .white)
    Box(center: (0, 0.55, 0), half: (0.6, 0.12, 0.5), color: .green)  // top pad
  }
}
