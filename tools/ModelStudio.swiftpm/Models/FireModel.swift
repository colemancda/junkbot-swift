/// Fire: a dark base with three tall flame cones plus a brighter inner flame.
enum FireModel {
  static let model = Model("Fire") {
    Box(center: (0, -0.75, 0), half: (0.9, 0.1, 0.5), color: .darkGray)  // base
    Cone(base: (-0.45, -0.65, 0), radius: 0.3, height: 0.8, color: .flame)
    Cone(base: (0.0, -0.65, 0), radius: 0.35, height: 1.15, color: .flame)
    Cone(base: (0.45, -0.65, 0), radius: 0.3, height: 0.85, color: .flame)
    Cone(base: (0.0, -0.5, 0.05), radius: 0.2, height: 0.75, color: .flameInner)
  }
}
