/// Eyebot: a stationary gray enemy dominated by one big eye.
enum EyebotModel {
  static let model = Model("Eyebot") {
    Box(center: (0, 0, 0), half: (0.6, 0.6, 0.5), color: .gray)  // body
    Disc(center: (0, 0, 0.55), radius: 0.42, color: .white)  // eye white
    Disc(center: (0, 0, 0.58), radius: 0.18, color: .dark)  // pupil
  }
}
