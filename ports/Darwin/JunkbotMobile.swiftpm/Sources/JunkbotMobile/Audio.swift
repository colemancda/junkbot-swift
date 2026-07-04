import AVFoundation
import Foundation

// Sound-effect + music playback, mirroring `ports/SDL3/Sources/JunkbotSDL3/main.swift`'s real
// `SoundBoard`/`MusicPlayer` (SDL3_mixer-backed) verbatim - same SoundID/filename tables, just
// `.ogg`/`.wav` -> `.caf` (transcoded at build time by `Scripts/transcode-audio.sh`, since
// `AVAudioPlayer` can't decode Ogg Vorbis directly - see that script's doc comment). Built on
// `AVAudioPlayer` instead of `MIX_*`, since that's the native, dependency-free way to play short
// PCM/compressed clips on every Apple platform this port targets.

/// Wraps one in-flight sound-effect playback and self-removes from `SoundBoard`'s retaining
/// dictionary once finished - `AVAudioPlayer` doesn't keep itself alive, so something must hold
/// a strong reference for the duration of playback.
private final class ActiveSoundEffect: NSObject, AVAudioPlayerDelegate {
  let player: AVAudioPlayer
  var onFinish: (() -> Void)?

  init?(data: Data) {
    guard let player = try? AVAudioPlayer(data: data) else { return nil }
    self.player = player
    super.init()
    player.delegate = self
  }

  func play() {
    player.play()
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    onFinish?()
  }
}

/// Sound-effect playback, mirroring `src/game.js`'s `playSound(soundName)`/`hotResourcePaths` -
/// see `ports/SDL3/Sources/JunkbotSDL3/main.swift`'s `SoundBoard` for the original table this was
/// copied from (including provenance notes for the win/lose voice lines and menu sounds).
/// `GameEngine.onPlaySound` is int-keyed (`Types.swift`'s `SoundID`), so this maps id -> bundled
/// filename directly.
final class SoundBoard {
  /// `SoundID.rawValue -> TranscodedAudio/sound-effects/-relative path`. Matches
  /// `ports/SDL3`'s `SoundBoard.paths` exactly, `.ogg`/`.wav` -> `.caf`.
  private static let paths: [Int32: String] = [
    0: "turn1.caf",
    1: "blockpickup.caf",
    2: "blockdrop.caf",
    3: "blockclick.caf",
    4: "fall.caf",
    5: "headbonk1.caf",
    6: "eat1.caf",
    7: "garbage1.caf",
    8: "switch_click.caf",
    9: "switch_on.caf",
    10: "switch_off.caf",
    11: "fire.caf",
    12: "electricity1.caf",
    13: "undercover/laser_hit.caf",
    14: "robottouch4.caf",
    15: "shieldon2.caf",
    16: "h_powerup1.caf",
    17: "h_powerdown3.caf",
    18: "undercover/teleport.caf",
    19: "voice_ohyeah.caf",
    20: "voice_ouch.caf",
    21: "voice_uhoh.caf",
    22: "jump3.caf",
    23: "fan.caf",
    24: "drip1.caf",
    25: "drip2.caf",
    26: "drip3.caf",
    27: "lego-creator/undo-I0512.caf",
    // Menu sounds (MenuSoundID in Screens.swift, disjoint from the engine's SoundID range).
    100: "h_button1.caf",
    101: "h_powerup3.caf",
    102: "enter_level.caf",
  ]

  private var dataByID: [Int32: Data] = [:]
  /// Keeps every in-flight `ActiveSoundEffect` alive (keyed by identity) until it finishes, so
  /// overlapping playback of the same sound (e.g. rapid water drips) works - mirroring
  /// SDL_mixer's auto-pick-a-free-channel behavior instead of one reused player per sound.
  private var activeSounds: [ObjectIdentifier: ActiveSoundEffect] = [:]

  init(directory: URL) {
    for (id, filename) in Self.paths {
      let url = directory.appendingPathComponent(filename)
      guard let data = try? Data(contentsOf: url) else {
        FileHandle.standardError.write(Data("Failed to load sound effect \(url.path)\n".utf8))
        continue
      }
      dataByID[id] = data
    }
    if dataByID.count < Self.paths.count {
      FileHandle.standardError.write(
        Data("Loaded \(dataByID.count)/\(Self.paths.count) sound effects\n".utf8))
    }
  }

  func play(_ id: Int32) {
    guard let data = dataByID[id], let effect = ActiveSoundEffect(data: data) else { return }
    let key = ObjectIdentifier(effect)
    activeSounds[key] = effect
    effect.onFinish = { [weak self] in self?.activeSounds.removeValue(forKey: key) }
    effect.play()
  }
}

/// Background music, mirroring `ports/SDL3/Sources/JunkbotSDL3/main.swift`'s `MusicPlayer` -
/// same 5 randomized level-music playlists + fade-out stings, reconstructing
/// `Sources/JunkbotCore/Internal/movie_Sound Code.ls`'s playlist model as closely as the
/// available assets allow (see that file's doc comment for the full reconstruction rationale).
final class MusicPlayer {
  struct Group {
    let tracks: [String]
    let end: String?
  }

  /// Matches `ports/SDL3`'s `MusicPlayer.levelGroups` exactly, `.ogg` -> `.caf`.
  static let levelGroups: [Group] = [
    Group(tracks: ["lego1.1.caf", "lego1.2.caf", "lego1.3.caf"], end: "lego1.end.caf"),
    Group(
      tracks: ["demo_4.1.caf", "demo_4.3.caf", "demo_4.5.caf", "demo_4.6.caf"],
      end: "demo_4.end.caf"),
    Group(
      tracks: ["demo_5.1.caf", "demo_5.2.caf", "demo_5.7.caf", "demo_5.8.caf"],
      end: "demo_5.end.caf"),
    Group(
      tracks: ["demo_6.1.caf", "demo_6.2.caf", "demo_6.4.caf", "demo_6.5.caf"],
      end: "demo_6.end.caf"),
    Group(tracks: ["demo6_3.caf", "demo6_5.caf", "demo6_6.caf"], end: "demo6_end.caf"),
  ]

  private let directory: URL
  private var dataByFilename: [String: Data] = [:]
  private var currentGroup: Group?
  /// Reassigned to a fresh player on every track change - `AVAudioPlayer` has no equivalent of
  /// SDL3_mixer's persistent "track" object that can have its audio swapped in place.
  private var player: AVAudioPlayer?

  init(directory: URL) {
    self.directory = directory
  }

  private func data(for filename: String) -> Data? {
    if let cached = dataByFilename[filename] { return cached }
    let url = directory.appendingPathComponent(filename)
    guard let data = try? Data(contentsOf: url) else {
      FileHandle.standardError.write(Data("Failed to load music track \(url.path)\n".utf8))
      return nil
    }
    dataByFilename[filename] = data
    return data
  }

  /// Picks one of `levelGroups` at random and starts looping it.
  func startRandomLevelMusic() {
    currentGroup = Self.levelGroups.randomElement()
    playNextTrack()
  }

  private func playNextTrack() {
    guard let group = currentGroup, let filename = group.tracks.randomElement(),
      let data = data(for: filename), let newPlayer = try? AVAudioPlayer(data: data)
    else { return }
    player = newPlayer
    newPlayer.play()
  }

  /// Call once per frame (already wired up in `GameScene.swift`'s `update(_:)`): whenever the
  /// currently-playing track finishes, picks a fresh random track from the same group so the
  /// music loops forever - mirrors `ports/SDL3`'s poll-based `!MIX_TrackPlaying(track)` check.
  func update() {
    guard let player, currentGroup != nil, !player.isPlaying else { return }
    playNextTrack()
  }

  /// Stops the looping playlist, playing the current group's fade-out sting once first if it has
  /// one.
  func stop() {
    guard let group = currentGroup else { return }
    currentGroup = nil
    if let end = group.end, let data = data(for: end), let endPlayer = try? AVAudioPlayer(data: data) {
      player = endPlayer
      endPlayer.play()
    } else {
      player?.stop()
    }
  }
}
