#if canImport(UIKit)
import UIKit
import SpriteKit

/// iOS/tvOS: creates the window/`SKView`/`JunkbotScene`. UIKit's lifecycle is close enough
/// between the two platforms that one file covers both (added to both targets in the Xcode
/// project) - see `AppDelegate_macOS.swift` for the AppKit equivalent.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let window = UIWindow(frame: UIScreen.main.bounds)
    let viewController = GameViewController()
    window.rootViewController = viewController
    window.makeKeyAndVisible()
    self.window = window
    return true
  }
}

/// iOS must be locked to landscape only (tvOS has no orientation concept - always fullscreen).
final class GameViewController: UIViewController {
  override func loadView() {
    view = SKView(frame: UIScreen.main.bounds)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    guard let skView = view as? SKView else { return }
    skView.ignoresSiblingOrder = true
    let scene = JunkbotScene(size: skView.bounds.size)
    scene.scaleMode = .resizeFill
    skView.presentScene(scene)
  }

  #if os(iOS)
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    .landscape
  }
  override var prefersStatusBarHidden: Bool { true }
  #endif
}
#endif
