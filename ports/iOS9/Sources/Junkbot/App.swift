import SpriteKit
import JunkbotBackend
import JunkbotCore

// The app's entry point - the iOS 9 equivalent of the Darwin port's
// `GameViewController.swift`: once UIKit has launched, presents the one
// `JunkbotScene` in the backend's landscape `SKView`.

/// Kept for the app's lifetime; it also keeps the presented scene alive.
@MainActor var skView: SKView?

@main
struct JunkbotApp {
  static func main() {
    _ = jb_main { view in
      MainActor.assumeIsolated {
        presentGame(in: SKView(view!))
      }
    }
  }
}

@MainActor func presentGame(in view: SKView) {
  view.ignoresSiblingOrder = true
  // As on the Darwin port, the scene's fixed logical size matches the title
  // screen level's bounds, and `.aspectFit` scales it to the screen.
  gameEngine.loadLevel(titleScreenLevel)
  windowWidth = gameEngine.levelBounds.map { $0.width } ?? 900
  windowHeight = gameEngine.levelBounds.map { $0.height } ?? 675
  let scene = JunkbotScene(size: CGSize(width: CGFloat(windowWidth), height: CGFloat(windowHeight)))
  scene.scaleMode = .aspectFit
  view.presentScene(scene)
  skView = view
}
