#if os(tvOS)
import UIKit
import SpriteKit

/// tvOS-only entry point (the iOS target moved to `JunkbotMobile.swiftpm`, an App
/// Playground, which boots through a SwiftUI `App` instead of a `UIApplicationDelegate` - see
/// that package's `JunkbotMobileApp.swift`). Both share the same `GameViewController`
/// (`GameViewController.swift`) that actually hosts the `SKView`/`JunkbotScene`; only the
/// bootstrap differs. See `AppDelegate_macOS.swift` for the AppKit equivalent.
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
#endif
