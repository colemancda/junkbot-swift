#if canImport(UIKit)
import UIKit
import SpriteKit
import SceneKit
import JunkbotCore

/// Hosts the one `SKView`/`JunkbotScene` this app ever presents - shared between the tvOS
/// Xcode target's `AppDelegate_tvOS.swift` (sets this directly as `window.rootViewController`)
/// and the iOS `JunkbotMobile.swiftpm` App Playground (wraps this in a SwiftUI
/// `UIViewControllerRepresentable` instead, since App Playgrounds boot through a SwiftUI `App`,
/// not a `UIApplicationDelegate`). Locking to landscape only makes sense on iOS (phones/iPads
/// support portrait); tvOS has no orientation concept at all (always fullscreen), hence the
/// `#if os(iOS)` guard below.
///
/// Also hosts an `SCNView` (`scnView` global, `Scene3DManager.swift`) as a sibling *behind* the
/// `SKView` - the live 3D play-mode scene. The `SKView` stays on top always (it owns input
/// handling and draws menu chrome/HUD even in 3D mode); `JunkbotScene.update(_:)` toggles the
/// `SCNView`'s visibility and makes the `SKView`'s background transparent while 3D is active, so
/// the 3D scene shows through underneath (see `suppressWorldSpriteDrawing`'s doc comment in
/// `GameRender.swift`).
public final class GameViewController: UIViewController {
  public override func loadView() {
    let container = UIView(frame: UIScreen.main.bounds)

    let newSCNView = SCNView(frame: container.bounds)
    newSCNView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    newSCNView.scene = scene3DManager.scene
    newSCNView.pointOfView = scene3DManager.cameraNode
    newSCNView.isHidden = true
    newSCNView.backgroundColor = .black
    container.addSubview(newSCNView)
    scnView = newSCNView

    let skView = SKView(frame: container.bounds)
    // The view tracks whatever size its container (the tvOS `UIWindow` or the iOS Playground's
    // SwiftUI-hosted controller) actually gives it...
    skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    skView.allowsTransparency = true
    container.addSubview(skView)

    view = container
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    guard let skView = view.subviews.compactMap({ $0 as? SKView }).first else { return }
    skView.ignoresSiblingOrder = true
    // Load the title screen level before creating the scene, so its fixed logical size can match
    // the level's actual bounds instead of an arbitrary fixed guess - matching `ports/SDL3`'s
    // `main.swift` and `AppDelegate_macOS.swift`'s identical logic (see that file's doc comment).
    // `GameScene.swift`'s `didMove(to:)` calls `showTitleScreen()` afterward, which loads it
    // again as part of the real screen-state setup - not a redundancy introduced here.
    gameEngine.loadLevel(titleScreenLevel)
    windowWidth = gameEngine.levelBounds.map { $0.width } ?? 900
    windowHeight = gameEngine.levelBounds.map { $0.height } ?? 675
    let scene = JunkbotScene(size: CGSize(width: CGFloat(windowWidth), height: CGFloat(windowHeight)))
    // The scene stays fixed at that logical size - `.aspectFit` scales it uniformly to fill as
    // much of the actual screen as possible while preserving aspect ratio, matching
    // `ports/SDL3`/`ports/SDL2`'s own fixed-logical-size + scale-to-fit presentation instead of
    // stretching the camera viewport to show more/less of the world as the screen size changes.
    // See `AppDelegate_macOS.swift`'s identical comment for the macOS side of this.
    scene.scaleMode = .aspectFit
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
