import Foundation

/// The app's first user-facing preference: no `UserDefaults`/settings mechanism existed anywhere
/// in `ports/Darwin` before this (the only prior persisted state was `SaveData` in
/// `Screens.swift`, which is level-completion progress, not a preference). Kept as a plain
/// `UserDefaults`-backed global rather than introducing a whole settings-screen architecture for
/// one toggle - see `Screens.swift`'s title screen for where this is exposed to the player.
enum Settings {
  private static let render3DKey = "render3DEnabled"

  /// Whether play mode renders the live 3D scene (`Scene3DManager`) instead of the normal 2D
  /// `SpriteKitRenderer` path. Defaults to `false` (2D) - 3D mode is new and unproven relative to
  /// the sprite renderer every other port also uses. Only affects `.playing`/`.title`
  /// (`GameScene.swift`'s `update(_:)`); the level editor's drag-to-place interaction always
  /// stays 2D regardless of this setting (see `Scene3DManager`'s doc comment for why).
  @GameActor static var render3DEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: render3DKey) }
    set { UserDefaults.standard.set(newValue, forKey: render3DKey) }
  }
}
