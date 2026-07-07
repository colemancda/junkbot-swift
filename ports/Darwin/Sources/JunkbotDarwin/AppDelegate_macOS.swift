#if os(macOS)
import Cocoa
import SpriteKit
import MetalKit
import JunkbotCore

/// macOS-only: creates the window/`SKView`/`JunkbotScene`. Not shared with iOS/tvOS - see
/// `AppDelegate_tvOS.swift` for the UIKit equivalent (tvOS only now - iOS moved to
/// `JunkbotMobile.swiftpm`, see `ports/Darwin/README.md`).
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!

  /// Overrides `NSApplicationDelegate`'s own default `@main`-compatible `static func main()`
  /// (which just calls the classic `NSApplicationMain` C entry point) - that default relies on a
  /// storyboard/nib to instantiate the delegate and assign it to `NSApp.delegate`, and this
  /// project has neither (pure-code SpriteKit app). Without this override, `NSApp.delegate` stays
  /// `nil` forever, `applicationDidFinishLaunching` never runs, and the app sits in its event loop
  /// with zero windows - confirmed via `lldb`: `[NSApp delegate]` was `nil` at runtime.
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Load the title screen level before creating the window, so the window's default (and
    // minimum) size can match its actual bounds instead of an arbitrary fixed guess - matching
    // `ports/SDL3`'s `main.swift` exactly (including its 900x675 fallback for when bounds aren't
    // available). `GameScene.swift`'s `didMove(to:)` calls `showTitleScreen()` afterward, which
    // loads it again as part of the real screen-state setup - the same double-load `ports/SDL3`
    // itself already does, not a redundancy introduced here.
    gameEngine.loadLevel(titleScreenLevel)
    // Assigning the *global* `windowWidth`/`windowHeight` (not just local variables) is essential
    // here - every shared rendering/UI file (`Screens.swift`, `GameRender.swift`) reads those
    // globals for all its positioning/scaling math, so if they stay at `GameShell.swift`'s
    // 900x675 defaults while the scene itself is actually sized differently (e.g. 525x396 for
    // the real Title Screen level bounds), buttons and world content get positioned/scaled for a
    // canvas size that doesn't match the scene's real coordinate space at all.
    windowWidth = gameEngine.levelBounds.map { $0.width } ?? 900
    windowHeight = gameEngine.levelBounds.map { $0.height } ?? 675
    let contentRect = NSRect(x: 0, y: 0, width: CGFloat(windowWidth), height: CGFloat(windowHeight))
    window = NSWindow(
      contentRect: contentRect,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "Junkbot"
    window.center()
    // Don't allow shrinking below the default size - matches `ports/SDL3`'s
    // `window.setMinimumSize(width:height:)` call.
    window.minSize = contentRect.size
    // AppKit's automatic window-state restoration would otherwise reopen the window at whatever
    // size/position the user last left it at, silently overriding the freshly-computed initial
    // size above on every launch after the first - SDL windows don't participate in this system
    // at all, so disabling it here is what actually makes every launch start at the same
    // computed size, matching `ports/SDL3`'s behavior exactly rather than just on first launch.
    window.isRestorable = false
    // Without this, AppKit only sends `mouseMoved`/`mouseDragged` events while a button is held -
    // `GameScene.swift`'s `mouseMoved` override (menu-hover, focus-clearing, input-kind tracking)
    // needs plain hover motion too.
    window.acceptsMouseMovedEvents = true
    // Opts this window into the standard green-button/⌃⌘F fullscreen transition, and - combined
    // with actually entering fullscreen below - is what lets macOS 15's automatic Game Mode
    // engage at all: Game Mode requires both a game-category `LSApplicationCategoryType`
    // (`Junkbot-macOS-Info.plist` already sets `public.app-category.puzzle-games`) *and* the app
    // actually running fullscreen with no other visible windows - neither alone is enough.
    window.collectionBehavior.insert(.fullScreenPrimary)

    // A container hosting both an `MTKView` (the live 3D play-mode scene, behind, hidden by
    // default) and the `SKView` (on top always - it owns input handling and draws menu chrome/HUD
    // even in 3D mode) - see `Metal3DManager.swift`'s doc comment (macOS renders 3D mode via
    // Metal, not SceneKit - `GameViewController.swift`'s iOS/tvOS setup is unaffected and still
    // uses `SCNView`/`Scene3DManager`).
    let container = NSView(frame: contentRect)
    container.autoresizingMask = [.width, .height]

    let newMTKView = MTKView(frame: contentRect)
    newMTKView.autoresizingMask = [.width, .height]
    if let manager = metal3DManager {
      manager.attach(to: newMTKView)
    }
    newMTKView.isHidden = true
    newMTKView.wantsLayer = true
    newMTKView.layer?.backgroundColor = NSColor.black.cgColor
    container.addSubview(newMTKView)
    metalView = newMTKView

    let view = SKView(frame: contentRect)
    view.ignoresSiblingOrder = true
    // The view tracks the window's actual (resizable) size...
    view.autoresizingMask = [.width, .height]
    view.allowsTransparency = true
    let scene = JunkbotScene(size: contentRect.size)
    // ...while the *scene* stays fixed at that same logical size - `.aspectFit` scales it
    // uniformly (fractionally, not integer-only) to fill as much of the actual window as
    // possible while preserving aspect ratio, matching `ports/SDL3`/`ports/SDL2`'s own
    // fixed-logical-size + scale-to-fit presentation (`.integerScale`) instead of stretching the
    // camera viewport to show more/less of the world as the window resizes (`.resizeFill`, tried
    // and reverted - it left large blank areas around a small level's actual content once the
    // window grew past the level's own bounds, since there's nothing beyond them to draw).
    scene.scaleMode = .aspectFit
    view.presentScene(scene)
    container.addSubview(view)
    window.contentView = container
    window.makeKeyAndOrderFront(nil)
    // Launch straight into fullscreen rather than requiring the user to click the window's
    // fullscreen button manually - `.aspectFit`'s scale-to-fit presentation already looks right
    // at any size, so there's no windowed-only content to lose. Dispatched to the next run-loop
    // turn since `toggleFullScreen(nil)` needs the window already on screen (from
    // `makeKeyAndOrderFront` above) to animate correctly.
    DispatchQueue.main.async { [self] in
      window.toggleFullScreen(nil)
    }

    // `GamepadInput.swift`'s `GCKeyboard`-routed keyDown handling (shared with iOS/tvOS) covers
    // arrows/space/return fine, but `GCKeyboard` on macOS does not reliably report the Escape key
    // - it's reserved/intercepted below the level GameController's HID monitoring sees. A local
    // `NSEvent` monitor (guaranteed to see every keyDown while this app is key, independent of
    // GameController) is the standard macOS-side workaround; `GamepadInput.swift`'s own `.escape`
    // case is compiled out on macOS (`#if !os(macOS)`) to avoid a double-fire if that ever changes.
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      if event.keyCode == 53 /* kVK_Escape */ {
        Task { @MainActor in escapePressed() }
        return nil
      }
      // Cmd+2 (force 2D) / Cmd+3 (force 3D) - mirrors the title screen's 3D/2D button
      // (`Screens.swift`'s `setRender3DEnabled`). Only meaningful on macOS ("Cmd" is Mac
      // terminology), so kept in this local monitor alongside Escape rather than in
      // `GamepadInput.swift`'s cross-platform `GCKeyboard` handler.
      if event.modifierFlags.contains(.command) {
        if event.keyCode == 19 /* ANSI_2 */ {
          Task { @MainActor in setRender3DEnabled(false) }
          return nil
        }
        if event.keyCode == 20 /* ANSI_3 */ {
          Task { @MainActor in setRender3DEnabled(true) }
          return nil
        }
      }
      return event
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
#endif
