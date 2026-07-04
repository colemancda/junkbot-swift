#if os(macOS)
import Cocoa
import SpriteKit

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
    gameEngine.loadLevel(fromText: readLevelText(at: titleScreenLevelURL) ?? "")
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

    let view = SKView(frame: contentRect)
    view.ignoresSiblingOrder = true
    // The view tracks the window's actual (resizable) size...
    view.autoresizingMask = [.width, .height]
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
    window.contentView = view
    window.makeKeyAndOrderFront(nil)

    // `GamepadInput.swift`'s `GCKeyboard`-routed keyDown handling (shared with iOS/tvOS) covers
    // arrows/space/return fine, but `GCKeyboard` on macOS does not reliably report the Escape key
    // - it's reserved/intercepted below the level GameController's HID monitoring sees. A local
    // `NSEvent` monitor (guaranteed to see every keyDown while this app is key, independent of
    // GameController) is the standard macOS-side workaround; `GamepadInput.swift`'s own `.escape`
    // case is compiled out on macOS (`#if !os(macOS)`) to avoid a double-fire if that ever changes.
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      guard event.keyCode == 53 /* kVK_Escape */ else { return event }
      Task { @MainActor in escapePressed() }
      return nil
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
#endif
