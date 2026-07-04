import SwiftUI
import UIKit

/// App Playground entry point (replaces the old `Junkbot-iOS` Xcode target, which booted
/// through a `UIApplicationDelegate` - see `ports/Darwin/README.md`). App Playgrounds boot
/// through a SwiftUI `App`/`Scene` instead, so this wraps the same `GameViewController`
/// (`GameViewController.swift`, shared with the tvOS Xcode target) in a
/// `UIViewControllerRepresentable` rather than duplicating its SpriteKit setup.
@main
struct JunkbotMobileApp: App {
  var body: some Scene {
    WindowGroup {
      GameView()
        .ignoresSafeArea()
        .statusBarHidden()
    }
  }
}

private struct GameView: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> GameViewController {
    GameViewController()
  }

  func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}
