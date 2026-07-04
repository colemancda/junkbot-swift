import Foundation
import JunkbotCore
import SpriteKit

// The Darwin-only globals that `Screens.swift`/`GameRender.swift`/`GameInput.swift` (shared with
// `ports/SDL3`/`ports/SDL2` via direct file reference/symlink) expect every port to provide -
// mirroring the equivalent section of `ports/SDL3/Sources/JunkbotSDL3/main.swift`, minus
// everything that's genuinely SDL-specific (window/renderer setup, the SDL event loop, gamepad
// polling - see `GameScene.swift` for the SpriteKit-driven replacement of the latter two).

// MARK: - Repo-relative paths

/// Locates the directory containing `images/`, `font/`, `levels/`, `audio/`. Unlike the SDL
/// ports (which read loose files relative to the built executable), this app bundles those
/// directories as Xcode folder references in Copy Bundle Resources - `Bundle.main.resourceURL`
/// already points at exactly that layout with no extra lookup needed.
let repoRoot: URL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
let levelsDirectory = repoRoot.appendingPathComponent("levels")
let spritesDirectory = repoRoot.appendingPathComponent("images/sprites")
let spritesUndercoverDirectory = spritesDirectory.appendingPathComponent("Undercover Exclusive")
let backgroundsDirectory = repoRoot.appendingPathComponent("images/backgrounds")
let backgroundsUndercoverDirectory = backgroundsDirectory.appendingPathComponent("Undercover Exclusive")
/// Where the `.caf`-transcoded audio assets live: written by `Scripts/transcode-audio.sh` at
/// build time for the Xcode targets (macOS/tvOS Run Script build phases), or checked in directly
/// under `JunkbotMobile.swiftpm/Sources/JunkbotMobile/TranscodedAudio/` for the iOS
/// Playground (SwiftPM plugins run sandboxed with no opt-out, and `afconvert` can't decode Ogg
/// Vorbis from inside that sandbox, so this has to be transcoded manually ahead of time there
/// instead - see that package's `Package.swift`) - see `Audio.swift`'s doc comment for why the
/// checked-in `audio/` originals (mostly Ogg Vorbis) can't be played directly via `AVAudioPlayer`.
let transcodedSoundEffectsDirectory = repoRoot.appendingPathComponent("TranscodedAudio/sound-effects")
let transcodedMusicDirectory = repoRoot.appendingPathComponent("TranscodedAudio/music")

/// Reads a level `.txt` file as UTF-8, stripping a leading byte-order-mark if present - see the
/// identical helper in `ports/SDL3/Sources/JunkbotSDL3/main.swift` for why this is needed.
func readLevelText(at url: URL) -> String? {
  guard var text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
  if text.hasPrefix("\u{FEFF}") {
    text.removeFirst()
  }
  return text
}

/// Building/basement grouping + listing - shared with every native target
/// (`Sources/JunkbotCore/LevelCatalog.swift`).
let levelCatalog = LevelCatalog(repoRoot: repoRoot)

// MARK: - Neutral wrapper functions for the shared, symlinked files

/// `Screens.swift` needs a monotonic clock and a way to open an external URL (the Credits
/// button) without statically importing any SDL/platform module itself (Swift's `import` is
/// file-scoped, and this file can't import both an SDL C module and Darwin's own APIs at once
/// in a way that would work across every port).
func currentTicksNanoseconds() -> UInt64 {
  UInt64(DispatchTime.now().uptimeNanoseconds)
}

func openExternalURL(_ url: String) {
  guard let target = URL(string: url) else { return }
  #if canImport(UIKit)
  UIApplication.shared.open(target)
  #else
  NSWorkspace.shared.open(target)
  #endif
}

// MARK: - Engine + camera

let gameEngine = GameEngine()

/// The `GameRenderer` every shared drawing file (`Screens.swift`, `TextRenderer.swift`,
/// `GameRender.swift`) draws through - see `Renderer.swift`. Unlike the SDL ports (where this is
/// a `let` built immediately from an already-created `SDL_Renderer`), SpriteKit's scene/view
/// aren't ready until `JunkbotScene.didMove(to:)` runs, so this starts nil and is assigned there.
@MainActor var gameRenderer: GameRenderer!

/// World-space camera center/scale - see the identical section in `ports/SDL3`'s `main.swift`.
@MainActor var cameraCenterX: Double = 0
@MainActor var cameraCenterY: Double = 0
@MainActor var cameraScale: Double = 1

/// The scene's own logical size in points - updated by `JunkbotScene.didChangeSize`/`didMove`,
/// read by every world/camera calculation the shared files perform. With `.resizeFill`
/// (`AppDelegate_macOS.swift`/`GameViewController.swift`), the scene's size always tracks the
/// real window/screen size exactly (no scaling, no letterboxing), so this changes whenever the
/// window/screen does.
@MainActor var windowWidth: Int32 = 900
@MainActor var windowHeight: Int32 = 675

@MainActor func updateCamera() {
  guard let junkbot = gameEngine.entities.first(where: { $0.type == .junkbot }) else { return }
  var targetX = Double(junkbot.x) + Double(junkbot.width) / 2
  var targetY = Double(junkbot.y) + Double(junkbot.height) / 2

  if let bounds = gameEngine.levelBounds {
    let halfViewWidth = Double(windowWidth) / 2 / cameraScale
    let halfViewHeight = Double(windowHeight) / 2 / cameraScale
    let minX = Double(bounds.x) + halfViewWidth
    let maxX = Double(bounds.x) + Double(bounds.width) - halfViewWidth
    let minY = Double(bounds.y) + halfViewHeight
    let maxY = Double(bounds.y) + Double(bounds.height) - halfViewHeight
    targetX = minX > maxX ? Double(bounds.x) + Double(bounds.width) / 2 : min(max(targetX, minX), maxX)
    targetY = minY > maxY ? Double(bounds.y) + Double(bounds.height) / 2 : min(max(targetY, minY), maxY)
  }

  cameraCenterX = targetX
  cameraCenterY = targetY
}

// MARK: - Input-kind (required by `GameRender.swift`'s `render()`, and by the shared
// `MenuFocus.swift`)
//
// `PointingInputKind` itself lives in `Sources/JunkbotCore/PointingInputKind.swift`, shared with
// `ports/SDL3`'s `Input.swift`. `focusedButtonIndex` (keyboard/d-pad menu focus index) is
// declared in the shared, symlinked `MenuFocus.swift`, not here - actually driven by
// `GamepadInput.swift`'s `GCController`/`GCKeyboard` handling.
@MainActor var lastPointingInput: PointingInputKind = .mouse
@MainActor var virtualCursorVisible = false

// MARK: - Audio
//
// `SoundBoard`/`MusicPlayer` themselves live in `Audio.swift` (AVAudioPlayer-backed, mirroring
// `ports/SDL3`'s SDL3_mixer-backed versions) - just instantiated here, matching the identical
// instantiation in `ports/SDL3`'s `main.swift`.

@MainActor let soundBoard = SoundBoard(directory: transcodedSoundEffectsDirectory)
@MainActor let musicPlayer = MusicPlayer(directory: transcodedMusicDirectory)

/// Called once from `JunkbotScene.didMove(to:)` - top-level statements (as opposed to
/// declarations) aren't allowed outside a file literally named `main.swift`, which this isn't
/// (an app target's entry point is `@main`, not a script file).
@MainActor func configureGameEngineCallbacks() {
  gameEngine.onPlaySound = { [soundBoard] id in soundBoard.play(id) }
}
