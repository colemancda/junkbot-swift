#if os(macOS)
import Cocoa
import SpriteKit

/// macOS-only: creates the window/`SKView`/`JunkbotScene`. Not shared with iOS/tvOS - see
/// `AppDelegate_iOS.swift` for the UIKit equivalent (used by both those targets, whose lifecycle
/// APIs are identical for this app's needs).
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!

  func applicationDidFinishLaunching(_ notification: Notification) {
    let contentRect = NSRect(x: 0, y: 0, width: 900, height: 675)
    window = NSWindow(
      contentRect: contentRect,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "Junkbot"
    window.center()

    let view = SKView(frame: contentRect)
    view.ignoresSiblingOrder = true
    let scene = JunkbotScene(size: contentRect.size)
    scene.scaleMode = .resizeFill
    view.presentScene(scene)
    window.contentView = view
    window.makeKeyAndOrderFront(nil)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
#endif
