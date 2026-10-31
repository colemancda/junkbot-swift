import Foundation
import JunkbotBackend

// Sound effects and music over AVAudioPlayer, through the backend - the same
// tables and playlist behavior as the Darwin port's `Audio.swift`, which plays
// the same transcoded `.caf` files.

/// A file's contents, loaded once for playing any number of times.
final class AudioClip {
  let pointer: UnsafeMutableRawPointer

  init?(url: URL) {
    guard let pointer = jb_audio_load(url.path) else {
      FileHandle.standardError.write(Data("Failed to load \(url.path)\n".utf8))
      return nil
    }
    self.pointer = pointer
  }

  /// Starts playing, returning the player, which plays to the end even if
  /// released.
  func play() -> AudioPlayer? {
    jb_audio_play(pointer).map(AudioPlayer.init)
  }

  deinit {
    jb_release(pointer)
  }
}

final class AudioPlayer {
  let pointer: UnsafeMutableRawPointer

  init(_ pointer: UnsafeMutableRawPointer) {
    self.pointer = pointer
  }

  var isPlaying: Bool {
    jb_audio_is_playing(pointer) != 0
  }

  func stop() {
    jb_audio_stop(pointer)
  }

  deinit {
    jb_release(pointer)
  }
}

final class SoundBoard {
  /// `SoundID.rawValue` -> path under `TranscodedAudio/sound-effects`, as on
  /// the Darwin port.
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
    // Menu sounds (MenuSoundID in Screens.swift).
    100: "h_button1.caf",
    101: "h_powerup3.caf",
    102: "enter_level.caf",
  ]

  private let directory: URL
  /// Loaded on first play, so launch doesn't read every file.
  private var clips: [Int32: AudioClip] = [:]

  init(directory: URL) {
    self.directory = directory
  }

  func play(_ id: Int32) {
    if clips[id] == nil {
      guard let path = Self.paths[id], let clip = AudioClip(url: directory.appendingPathComponent(path)) else {
        return
      }
      clips[id] = clip
    }
    _ = clips[id]?.play()
  }
}

final class MusicPlayer {
  struct Group {
    let tracks: [String]
    let end: String?
  }

  /// The Darwin port's level playlists.
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
  private var currentGroup: Group?
  private var player: AudioPlayer?

  init(directory: URL) {
    self.directory = directory
  }

  /// Music tracks are large, so they're read each time they start rather
  /// than kept in memory.
  private func play(_ filename: String) {
    player?.stop()
    player = AudioClip(url: directory.appendingPathComponent(filename))?.play()
  }

  func startRandomLevelMusic() {
    currentGroup = Self.levelGroups.randomElement()
    playNextTrack()
  }

  private func playNextTrack() {
    guard let group = currentGroup, let filename = group.tracks.randomElement() else { return }
    play(filename)
  }

  /// Called every frame: loops the playlist when a track ends.
  func update() {
    guard let player, currentGroup != nil, !player.isPlaying else { return }
    playNextTrack()
  }

  /// Stops the playlist, playing its closing sting if it has one.
  func stop() {
    guard let group = currentGroup else { return }
    currentGroup = nil
    if let end = group.end {
      play(end)
    } else {
      player?.stop()
    }
  }
}
