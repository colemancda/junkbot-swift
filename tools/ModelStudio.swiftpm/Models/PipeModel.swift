/// Pipe: a horizontal cylinder with a darker band around its middle.
enum PipeModel {
  static let model = Model("Pipe") {
    CylinderX(center: (0, 0, 0), radius: 0.5, halfLength: 1.1, color: .pipe)
    CylinderX(center: (0, 0, 0), radius: 0.55, halfLength: 0.12, color: .darkGray)  // band
  }
}
