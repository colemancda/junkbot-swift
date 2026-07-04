// Android entry points for the Junkbot shared library.
//
// Lifecycle: MainActivity (a Java SDLActivity subclass, see AndroidApp/) calls
// `System.loadLibrary("JunkbotAndroid")`, which triggers `JNI_OnLoad` below on the JVM main
// thread; SDL's Java side then spins up its dedicated native thread and calls the exported
// `SDL_main`, which extracts the APK's bundled game assets to internal storage (first launch
// only), installs a real `AndroidMainActor` (see `GameActor.swift`) on this thread, and finally
// hands control to the shared `junkbotMain()` game loop from ports/SDL3 through that actor.

import Foundation
import CSDL3
import CAndroidLooper
import JunkbotGame
import AndroidLogging
import AndroidContext
import AndroidFileManager
import AndroidLooper
import SwiftJavaJNICore

private let logger = AndroidLogger(tag: "Junkbot")
private func log(_ message: String) { try? logger.log(message) }

/// Called by the JVM when MainActivity's `System.loadLibrary("JunkbotAndroid")` maps this
/// library. Registering the JVM here is what lets `AndroidContext.application` (used during
/// asset extraction) work without any fragile `dlopen("libart.so")` fallback - that path is
/// blocked by Android's linker namespaces for app code on modern API levels.
@_cdecl("JNI_OnLoad")
public func junkbotJNIOnLoad(_ jvm: JavaVMPointer, _ reserved: UnsafeMutableRawPointer?) -> jint {
  JavaVirtualMachine.setSharedJVM(JavaVirtualMachine(adoptingJVM: jvm))
  return jint(0x0001_0006)  // JNI_VERSION_1_6
}

/// The symbol SDL's Java glue (`SDLActivity.nativeRunMain`) looks up in this library and calls
/// on SDL's dedicated native thread - the Android equivalent of the desktop executable's `main`.
@_cdecl("SDL_main")
public func junkbotSDLMain(
  _ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
  do {
    let assetRoot = try extractBundledAssets()
    assetRootOverridePath = assetRoot
    log("Game assets ready at \(assetRoot)")
  } catch {
    log("FATAL: bundled-asset extraction failed: \(error)")
    return 1
  }

  // `AndroidMainActor` needs a native `ALooper` associated with the calling thread before it can
  // find one via `ALooper_forThread()` - this pthread (SDL's dedicated "SDLThread") doesn't have
  // one prepared by default, unlike a thread the JVM itself spun up as a `Looper`-backed
  // `HandlerThread`. `Looper.currentThread(options:)` prepares and retains one - crucially, that
  // retained reference must be kept alive (bound to `mainThreadLooper` below, never discarded)
  // for as long as this thread runs: `Looper` is `~Copyable`, and its `deinit` calls
  // `ALooper_release` unconditionally, so discarding the result immediately (e.g. `_ = ...`)
  // releases the looper right back down to zero references and frees it before
  // `setupMainLooper()` ever runs - its subsequent `ALooper_forThread()` call then returns a
  // dangling pointer into already-freed memory, which crashes with a SIGSEGV inside
  // `setupMainLooper()` itself (confirmed on-device - this is not a hypothetical). Once installed,
  // `setupMainLooper()` makes `AndroidMainActor`'s looper-backed executor isolate every
  // `@GameActor` global in the shared game code (see `GameActor.swift`) to genuinely, dynamically
  // *this* thread - not just documented as single-threaded and hoping for the best.
  let mainThreadLooper = Looper.currentThread(options: [])
  guard AndroidMainActor.setupMainLooper() else {
    log("FATAL: failed to install AndroidMainActor's looper executor on the SDL thread")
    return 1
  }

  // Hands the actual game off to the newly-installed executor. `junkbotMain()` never returns (its
  // own event/tick/render loop runs until the app quits), so once this job starts running it
  // permanently occupies the executor - there's only ever this one job, so nothing else needs to
  // interleave with it.
  Task { @GameActor in
    junkbotMain()
  }

  // `AndroidMainActor`'s executor only drains its job queue from a callback that fires when
  // something actually polls this thread's looper (see `installGlobalExecutor` upstream) - but
  // swift-android-native's own `Looper`/`Looper.Handle.pollOnce` are `internal` at the version
  // this resolves to, so there's no public API to drive that poll ourselves. Call the raw NDK
  // function directly instead (`CAndroidLooper`, a local shim around `<android/looper.h>`) - this
  // is exactly what that internal wrapper would have called anyway. Nothing but the Task above
  // ever schedules other `@GameActor` work on this process, so this loop only has to keep polling
  // until that one job is dequeued and starts running (its `enqueue(_:)` call happens
  // synchronously as part of creating the `Task` above, so this is normally satisfied on the very
  // first or second iteration) - after that, control never returns here, since the job's own body
  // (`junkbotMain()`) never returns.
  while true {
    var outFd: Int32 = -1
    var outEvents: Int32 = 0
    var outData: UnsafeMutableRawPointer?
    _ = ALooper_pollOnce(100, &outFd, &outEvents, &outData)
  }
}

// MARK: - Asset extraction

private enum AssetError: Error {
  case noInternalStoragePath
  case manifestUnreadable
}

/// Copies the APK's bundled `assets/gameassets/**` tree (images/, font/, levels/, audio/ -
/// staged by the Gradle build, see AndroidApp/app/build.gradle) into
/// `<internal storage>/gameassets/`, returning that directory's path for use as the game's
/// asset root. The game code loads assets through plain `FileManager`/file-path APIs
/// (`IMG_Load`, `String(contentsOf:)`, directory scans), none of which can reach APK-packed
/// assets - a one-time extraction is the simplest bridge, and at ~8 MB it costs well under a
/// second on first launch.
///
/// The Gradle build also generates `assets/gameassets.manifest` ("path<TAB>bytes" per line,
/// since `AAssetDir` can't enumerate subdirectories); its hash doubles as the up-to-date stamp
/// so re-launches skip straight to the game, and app updates that change any asset re-extract.
private func extractBundledAssets() throws -> String {
  guard let cStoragePath = SDL_GetAndroidInternalStoragePath() else {
    throw AssetError.noInternalStoragePath
  }
  let rootURL = URL(fileURLWithPath: String(cString: cStoragePath), isDirectory: true)
    .appendingPathComponent("gameassets", isDirectory: true)

  let assets = try AndroidContext.application.assetManager
  let manifestText: String = try {
    let asset = try assets.open("gameassets.manifest", mode: .buffer)
    return try asset.readAll { buffer in
      guard let text = String(bytes: buffer, encoding: .utf8) else {
        throw AssetError.manifestUnreadable
      }
      return text
    }
  }()

  let stampURL = rootURL.appendingPathComponent(".manifest-stamp")
  let fingerprint = fnv1aHex(manifestText)
  if let existing = try? String(contentsOf: stampURL, encoding: .utf8), existing == fingerprint {
    return rootURL.path
  }

  log("Extracting bundled assets (first launch or app update)…")
  let fileManager = FileManager.default
  var extractedCount = 0
  for line in manifestText.split(whereSeparator: \.isNewline) {
    guard let relativePath = line.split(separator: "\t").first.map(String.init),
      !relativePath.isEmpty
    else { continue }
    let destination = rootURL.appendingPathComponent(relativePath)
    try fileManager.createDirectory(
      at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    let asset = try assets.open("gameassets/" + relativePath, mode: .streaming)
    try asset.readAll { (buffer: UnsafeRawBufferPointer) in
      let data =
        buffer.isEmpty ? Data() : Data(bytes: buffer.baseAddress!, count: buffer.count)
      try data.write(to: destination)
    }
    extractedCount += 1
  }
  try fingerprint.write(to: stampURL, atomically: true, encoding: .utf8)
  log("Extracted \(extractedCount) asset files to \(rootURL.path)")
  return rootURL.path
}

/// Tiny stable content hash for the manifest stamp - nothing cryptographic needed, it only has
/// to change when the asset list/sizes change.
private func fnv1aHex(_ text: String) -> String {
  var hash: UInt64 = 0xcbf2_9ce4_8422_2325
  for byte in text.utf8 {
    hash ^= UInt64(byte)
    hash = hash &* 0x0000_0100_0000_01b3
  }
  return String(hash, radix: 16)
}
