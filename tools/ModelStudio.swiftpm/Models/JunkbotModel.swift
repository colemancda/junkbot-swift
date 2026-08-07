/// Junkbot: the boxy robot - an orange crate torso, a yellow lid, a recycle badge and eyes on the
/// front, standing on a single gray leg + foot.
enum JunkbotModel {
  static let model = Model("Junkbot") {
    Box(center: (0, 0, 0), half: (0.9, 0.7, 0.7), color: .orange)  // torso
    Box(center: (0, 0.85, 0), half: (0.7, 0.15, 0.6), color: .yellow)  // lid
    Box(center: (-0.35, 0.15, 0.72), half: (0.12, 0.1, 0.05), color: .dark)  // eyes
    Box(center: (0.35, 0.15, 0.72), half: (0.12, 0.1, 0.05), color: .dark)
    Disc(center: (0, -0.25, 0.72), radius: 0.28, color: .darkGray)  // recycle badge
    Box(center: (0, -1.1, 0), half: (0.3, 0.4, 0.3), color: .gray)  // leg
    Box(center: (0, -1.55, 0.1), half: (0.5, 0.1, 0.4), color: .gray)  // foot
  }
}
