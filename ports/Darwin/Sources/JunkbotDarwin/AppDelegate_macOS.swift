#if os(macOS)
import Cocoa
import SpriteKit

/// macOS-only: creates the window/`SKView`/`JunkbotScene`. Not shared with iOS/tvOS - see
/// `AppDelegate_tvOS.swift` for the UIKit equivalent (tvOS only now - iOS moved to
/// `JunkbotPlayground.swiftpm`, see `ports/Darwin/README.md`).
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
    let contentRect = NSRect(x: 0, y: 0, width: 900, height: 675)
    window = NSWindow(
      contentRect: contentRect,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "Junkbot"
    window.center()
    // Without this, AppKit only sends `mouseMoved`/`mouseDragged` events while a button is held -
    // `GameScene.swift`'s `mouseMoved` override (menu-hover, focus-clearing, input-kind tracking)
    // needs plain hover motion too.
    window.acceptsMouseMovedEvents = true

    let view = SKView(frame: contentRect)
    view.ignoresSiblingOrder = true
    // The view tracks the window's actual (resizable) size...
    view.autoresizingMask = [.width, .height]
    let scene = JunkbotScene(size: contentRect.size)
    // ...and with `.resizeFill`, the *scene*'s size always matches the view's size exactly (no
    // scaling, no letterboxing) - `GameScene.swift`'s `didChangeSize` keeps `windowWidth`/
    // `windowHeight` in sync as the window resizes, so the game world fills the window edge to
    // edge at every size.
    scene.scaleMode = .resizeFill
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
