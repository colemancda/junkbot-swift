#if canImport(UIKit)
import UIKit
import SpriteKit

/// Hosts the one `SKView`/`JunkbotScene` this app ever presents - shared between the tvOS
/// Xcode target's `AppDelegate_tvOS.swift` (sets this directly as `window.rootViewController`)
/// and the iOS `JunkbotPlayground.swiftpm` App Playground (wraps this in a SwiftUI
/// `UIViewControllerRepresentable` instead, since App Playgrounds boot through a SwiftUI `App`,
/// not a `UIApplicationDelegate`). Locking to landscape only makes sense on iOS (phones/iPads
/// support portrait); tvOS has no orientation concept at all (always fullscreen), hence the
/// `#if os(iOS)` guard below.
public final class GameViewController: UIViewController {
  public override func loadView() {
    view = SKView(frame: UIScreen.main.bounds)
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    guard let skView = view as? SKView else { return }
    skView.ignoresSiblingOrder = true
    let scene = JunkbotScene(size: skView.bounds.size)
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
