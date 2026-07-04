#if canImport(UIKit)
import UIKit
import SpriteKit

/// Hosts the one `SKView`/`JunkbotScene` this app ever presents - shared between the tvOS
/// Xcode target's `AppDelegate_tvOS.swift` (sets this directly as `window.rootViewController`)
/// and the iOS `JunkbotMobile.swiftpm` App Playground (wraps this in a SwiftUI
/// `UIViewControllerRepresentable` instead, since App Playgrounds boot through a SwiftUI `App`,
/// not a `UIApplicationDelegate`). Locking to landscape only makes sense on iOS (phones/iPads
/// support portrait); tvOS has no orientation concept at all (always fullscreen), hence the
/// `#if os(iOS)` guard below.
public final class GameViewController: UIViewController {
  public override func loadView() {
    let skView = SKView(frame: UIScreen.main.bounds)
    // The view tracks whatever size its container (the tvOS `UIWindow` or the iOS Playground's
    // SwiftUI-hosted controller) actually gives it...
    skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view = skView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    guard let skView = view as? SKView else { return }
    skView.ignoresSiblingOrder = true
    let scene = JunkbotScene(size: skView.bounds.size)
    // ...and with `.resizeFill`, the *scene*'s size always matches the view's size exactly (no
    // scaling, no letterboxing) - `GameScene.swift`'s `didChangeSize` keeps `windowWidth`/
    // `windowHeight` in sync as the screen size changes, so the game world fills the screen edge
    // to edge. See `AppDelegate_macOS.swift`'s identical comment for the macOS side of this.
    scene.scaleMode = .resizeFill
    skView.presentScene(scene)
  }

  #if os(iOS)
  public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    .landscape
  }
  public override var prefersStatusBarHidden: Bool { true }
  #endif
}
#endif
