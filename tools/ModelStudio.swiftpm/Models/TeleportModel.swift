/// Teleport: a purple base pad, a lighter ring, and an energy column rising from it.
enum TeleportModel {
  static let model = Model("Teleport") {
    CylinderY(center: (0, -0.8, 0), radius: 0.9, halfHeight: 0.12, color: .purple)  // base pad
    CylinderY(center: (0, -0.55, 0), radius: 0.7, halfHeight: 0.06, color: .lightPurple)  // ring
    CylinderY(center: (0, 0.1, 0), radius: 0.32, halfHeight: 0.75, color: .lightPurple)  // column
  }
}
