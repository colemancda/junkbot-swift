/// Fan: a gray base with a two-blade cross and a hub facing the player.
enum FanModel {
  static let model = Model("Fan") {
    Box(center: (0, -0.7, 0), half: (0.8, 0.15, 0.6), color: .gray)  // base
    Box(center: (0, 0, 0.12), half: (0.75, 0.14, 0.04), color: .darkGray)  // blade
    Box(center: (0, 0, 0.12), half: (0.14, 0.75, 0.04), color: .darkGray)  // blade
    Disc(center: (0, 0, 0.16), radius: 0.16, color: .gray)  // hub
  }
}
