/// Laser: a dark emitter box with a red lens and a thin red beam.
enum LaserModel {
  static let model = Model("Laser") {
    Box(center: (-0.85, 0, 0), half: (0.3, 0.45, 0.45), color: .darkGray)  // emitter
    Disc(center: (-0.54, 0, 0.0), radius: 0.2, color: .red)  // lens
    CylinderX(center: (0.15, 0, 0), radius: 0.07, halfLength: 0.85, color: .red)  // beam
  }
}
