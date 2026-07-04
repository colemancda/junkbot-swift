import PackagePlugin

/// Transcodes `Sources/JunkbotPlayground/audio/{sound-effects,music}` (a symlink into the
/// repo-root `audio/` directory, mostly Ogg Vorbis - a format `AVAudioPlayer` can't decode) into
/// Core Audio Format (`.caf`) at build time, via the same `transcode-audio.sh` script
/// `Junkbot.xcodeproj`'s macOS/tvOS targets invoke as a Run Script build phase - see that
/// script's own doc comment for why `.ogg`/`.wav` stay the checked-in source of truth instead of
/// checking in pre-converted files or adding a third-party Ogg decoder dependency.
///
/// A `prebuildCommand` (not a plain `buildCommand`) because the exact set of audio files isn't
/// known until the script actually walks the source directory - the same reason
/// `swift-lingo`'s `LingoTranspilerPlugin` (already a dependency of this project, via
/// `JunkbotCore`) uses a prebuild command for its own dynamically-discovered `.ls` file set.
@main
struct TranscodeAudioPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
    let scriptPath = context.package.directory.appending(subpath: "../Scripts/transcode-audio.sh")
    let audioDirectory = context.package.directory.appending(
      subpath: "Sources/JunkbotPlayground/audio")
    // `GameShell.swift`'s `transcodedSoundEffectsDirectory`/`transcodedMusicDirectory` expect
    // `TranscodedAudio/sound-effects`/`TranscodedAudio/music` inside the app bundle - matching
    // the Xcode Run Script build phase's own output paths for the macOS/tvOS targets exactly
    // (`$BUILT_PRODUCTS_DIR/.../TranscodedAudio/sound-effects`). A generated resource's bundle
    // path is computed relative to the *declared* `outputFilesDirectory`, not relative to
    // wherever the script happens to write - so both commands below declare the shared
    // `pluginWorkDirectory` itself as the root (one level above the actual `TranscodedAudio`
    // folder the script writes into), which is what preserves the `TranscodedAudio/...` prefix
    // in the final bundle instead of it being stripped away.
    let transcodedRoot = context.pluginWorkDirectory.appending(subpath: "TranscodedAudio")

    return [
      .prebuildCommand(
        displayName: "Transcode sound effects (ogg/wav -> caf)",
        executable: scriptPath,
        arguments: [
          audioDirectory.appending(subpath: "sound-effects").string,
          transcodedRoot.appending(subpath: "sound-effects").string,
        ],
        outputFilesDirectory: context.pluginWorkDirectory
      ),
      .prebuildCommand(
        displayName: "Transcode music (ogg -> caf)",
        executable: scriptPath,
        arguments: [
          audioDirectory.appending(subpath: "music").string,
          transcodedRoot.appending(subpath: "music").string,
        ],
        outputFilesDirectory: context.pluginWorkDirectory
      ),
    ]
  }
}
