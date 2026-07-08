/// Bin: the blue recycling trash can - a round body, a dark rim, a gray lid, a recycle badge.
enum BinModel {
  static let model = Model("Bin") {
    CylinderY(center: (0, 0, 0), radius: 0.65, halfHeight: 0.8, color: .blue)  // body
    CylinderY(center: (0, 0.82, 0), radius: 0.72, halfHeight: 0.06, color: .darkGray)  // rim
    CylinderY(center: (0, 0.92, 0), radius: 0.68, halfHeight: 0.05, color: .gray)  // lid
    Disc(center: (0, 0.1, 0.66), radius: 0.32, color: .white)  // recycle badge
  }
}
